// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Săptămână $week';
  }

  @override
  String get addCourse => 'Adăugați curs';

  @override
  String get settings => 'Setări';

  @override
  String get multiTimetableSwitch => 'Comută programele';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Orarul curent · $weeks săptămâni';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Atingeți pentru a comuta · $weeks săptămâni';
  }

  @override
  String get editTimetable => 'Editați orarul';

  @override
  String get schoolImportResultEditorTitle => 'Editează rezultatul analizat';

  @override
  String get schoolImportParsePageTitle => 'Analizează orarul';

  @override
  String get schoolImportParsePageParsing => 'Se analizează…';

  @override
  String get schoolImportParsePageFailed => 'Analiza a eșuat';

  @override
  String get schoolImportParsePageComplete => 'Analiză finalizată';

  @override
  String get schoolImportParsePageContinue => 'Continuă';

  @override
  String get schoolImportParsePageRawContent => 'Răspuns brut';

  @override
  String get schoolImportParsePageExpandRaw => 'Extinde răspunsul brut';

  @override
  String get schoolImportParsePageCollapseRaw => 'Restrânge răspunsul brut';

  @override
  String get schoolImportExpandWarnings => 'Extinde avertismentele de import';

  @override
  String get schoolImportCollapseWarnings =>
      'Restrânge avertismentele de import';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Unele cursuri continuă până în săptămâna $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Înlocuiești orarul curent?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Orarul importat va înlocui orarul curent.';

  @override
  String get createTimetable => 'Orar nou';

  @override
  String get jumpToWeek => 'Salt la săptămână';

  @override
  String get timetable => 'Orarul';

  @override
  String get themeWorkspaceSchedule => 'Program';

  @override
  String get timetableName => 'Numele orarului';

  @override
  String get timetableNameRequired => 'Numele orarului este obligatoriu';

  @override
  String get totalWeeks => 'Total săptămâni';

  @override
  String get delete => 'Șterge';

  @override
  String get cancel => 'Anulează';

  @override
  String get save => 'Salvează';

  @override
  String get deleteTimetableTitle => 'Ştergerea orarului';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Ştergeţi \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Încă nu există orar';

  @override
  String get noTimetableMessage =>
      'Creați un orar sau importați unul dintr-un fișier JSON.';

  @override
  String get importTimetable => 'Import orar';

  @override
  String get courseName => 'Numele cursului';

  @override
  String get location => 'Locație';

  @override
  String get dayOfWeek => 'Ziua';

  @override
  String get semesterWeeks => 'Săptămâni';

  @override
  String get startTime => 'Ora de începere';

  @override
  String get endTime => 'Ora de sfârşit';

  @override
  String get linkedPeriods => 'Perioadele legate';

  @override
  String get linkedPeriodsUnmatched =>
      'Nu se potrivesc perioade pentru ora curentă. Atingeți pentru a alege manual.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Perioada $start-$end';
  }

  @override
  String get teacherName => 'Profesor';

  @override
  String get credits => 'Credite';

  @override
  String get remarks => 'Observații';

  @override
  String get customFields => 'Câmpuri personalizate';

  @override
  String get customFieldsHint => 'Unul pe linie, format: cheie:valoare';

  @override
  String get customFieldsInvalidJson =>
      'Introdu un obiect JSON valid sau golește câmpul.';

  @override
  String get more => 'Mai multe';

  @override
  String get selectDayOfWeek => 'Alegeți ziua';

  @override
  String get selectSemesterWeeks => 'Alegeți săptămâni';

  @override
  String get selectAll => 'Selectați toate';

  @override
  String get clear => 'Curge';

  @override
  String get confirm => 'Confirmă';

  @override
  String get selectLinkedPeriods => 'Alegeți perioadele legate';

  @override
  String get addCourseTitle => 'Adăugați curs';

  @override
  String get editCourseTitle => 'Editați cursul';

  @override
  String get editCourseTooltip => 'Editați cursul';

  @override
  String get place => 'Locație';

  @override
  String get time => 'Timpul';

  @override
  String get notFilled => 'Nu este umplut';

  @override
  String get none => 'Niciun';

  @override
  String get conflictCourses => 'Cursuri în conflict';

  @override
  String get locationNotFilled => 'Locația nu este umplută';

  @override
  String get setAsDisplayed => 'Setați ca afișat';

  @override
  String get editThisCourse => 'Editați acest curs';

  @override
  String get settingsTitle => 'Setări';

  @override
  String get settingsSectionTimetable => 'Orar';

  @override
  String get settingsSectionGeneralSchedule => 'Program general';

  @override
  String get settingsSectionAppearance => 'Aspect';

  @override
  String get settingsSectionApp => 'Aplicație';

  @override
  String get settingsSectionWorkspace => 'Spațiu de lucru';

  @override
  String get settingsSectionAppearanceLanguage => 'Aspect și limbă';

  @override
  String get settingsSectionDataSecurity => 'Date și securitate';

  @override
  String get settingsSectionAbout => 'Despre Sked';

  @override
  String get noTimetableSettings =>
      'În prezent nu este disponibil niciun orar pentru setări.';

  @override
  String get semesterStartDate => 'Data începerii semestrului';

  @override
  String get periodTimeSets => 'Perioada de timp stabilită';

  @override
  String get noPeriodTimeAvailable => 'Nici o perioadă de timp disponibilă';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count perioade';
  }

  @override
  String get coursePopupDismissSetting =>
      'Permiteți atingerea din afară pentru a închide pop-up-ul cursului';

  @override
  String get coursePopupDismissSettingHint =>
      'Oprirea acestui lucru dezactivează, de asemenea, concedierea cu glisarea în jos.';

  @override
  String get preserveTimetableGaps => 'Păstrați lacunele programului';

  @override
  String get preserveTimetableGapsHint =>
      'Când sunt libere, prânzul și pauza se prăbușesc, astfel încât clasele ulterioare se mută în sus.';

  @override
  String get showPastEndedCourses => 'Afișează cursurile încheiate în trecut';

  @override
  String get showPastEndedCoursesHint =>
      'Afișați cursurile care au terminat deja săptămâna actuală reală cu un stil gri deschis.';

  @override
  String get showFutureCourses => 'Afișați cursurile viitoare';

  @override
  String get showFutureCoursesHint =>
      'Afișați cursuri care nu sunt active în această săptămână, dar vor apărea în săptămânile ulterioare cu un stil gri.';

  @override
  String get timetableDisplaySettings => 'Afișarea orarului și interacțiunea';

  @override
  String get timetableDisplaySettingsDesc =>
      'Afișarea cursurilor, aspectul, gesturile săptămânale și adăugarea rapidă';

  @override
  String get showTimetableGridLines => 'Afișează liniile grilei de orar';

  @override
  String get showTimetableGridLinesHint =>
      'Controlați dacă liniile de rețea orizontale și verticale sunt vizibile în orar.';

  @override
  String get timetableHorizontalLayoutSection => 'Aspect orizontal și gesturi';

  @override
  String get fitDaySelectorToWidth => 'Încadrează selectorul de zile pe ecran';

  @override
  String get fitDaySelectorToWidthHint =>
      'Afișează toate cele șapte zile pe ecran când este posibil; dezactivează pentru lățime fixă și derulare.';

  @override
  String get fitWeekColumnsToWidth =>
      'Încadrează coloanele săptămânii pe ecran';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Afișează toate cele șapte coloane ale orarului pe ecran când este posibil; dezactivează pentru lățime fixă și derulare.';

  @override
  String get enableWeekSwipeNavigation => 'Schimbă săptămânile prin glisare';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Glisează la stânga sau la dreapta pentru altă săptămână. La lățime fixă, trage mai întâi dincolo de margine.';

  @override
  String get liveCourseOutlineColor => 'Culoarea conturului cursului';

  @override
  String get liveCourseOutlineColorHint =>
      'Alegeți dacă conturile vizează cursul curent / următor sau toate cursurile afișate pe pagina curentă.';

  @override
  String get liveCourseOutlineSettings => 'Descriere curs';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Configurați dacă conturul este activat, ce vizează, dacă urmează culoarea temei și culoarea efectivă a conturului.';

  @override
  String get liveCourseOutlineEnabled => 'Activează contorul';

  @override
  String get liveCourseOutlineFollowTheme => 'Urmăriți culoarea temei';

  @override
  String get liveCourseOutlineTarget => 'Obiectivul general';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Cursul curent/următor';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Toate cursurile afișate';

  @override
  String get liveCourseOutlineEffectiveColor => 'Culoare eficientă';

  @override
  String get liveCourseOutlineCustomColor => 'Culoare contour personalizată';

  @override
  String get liveCourseOutlineWidth => 'Lățimea conturului';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Limbă';

  @override
  String get languagePageDescription =>
      'Alegeți una dintre limbile care sunt cu adevărat disponibile în aplicație.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'engleză';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Răspunsul API';

  @override
  String get theme => 'Tema';

  @override
  String get themeFollowSystem => 'Urmăriți sistemul';

  @override
  String get themeLight => 'Lumină';

  @override
  String get themeDark => 'Întunecat';

  @override
  String get themeColor => 'Culoarea temei';

  @override
  String get themeColorModeSingle => 'Culoare temă unică';

  @override
  String get themeColorModeColorful => 'Colorate';

  @override
  String get themeColorUiColors => 'Culori UI';

  @override
  String get themeColorCourseColors => 'Culorile cursului';

  @override
  String get themeColorPrimary => 'Primară';

  @override
  String get themeColorSecondary => 'secundară';

  @override
  String get themeColorTertiary => 'Terțiar';

  @override
  String get themeColorCourseText => 'Textul cursului';

  @override
  String get themeColorCourseTextAuto => 'Automat';

  @override
  String get themeColorCourseTextCustom => 'Culoare personalizată';

  @override
  String get themeColorCourseColorsEmpty =>
      'Culorile cursului vor fi generate după importarea unui orar.';

  @override
  String get themeCustomColor => 'Culoare personalizată';

  @override
  String get themeApplyCustomColor => 'Aplică culoare';

  @override
  String get themeApplySettings => 'Aplică setările';

  @override
  String get dataImportExport => 'Import și export de date';

  @override
  String get dataImportExportDesc =>
      'Importați date complete sau orare unice sau exportați orarele curente/toate.';

  @override
  String get appBackupTitle => 'Backup și restaurare aplicație';

  @override
  String get appBackupSubtitle =>
      'Fă backup sau restaurează orare, programe, setări și site-uri școlare. Cheile API nu sunt incluse.';

  @override
  String get appBackupSheetSubtitle =>
      'O restaurare completă înlocuiește datele curente ale aplicației. Cheile AI API rămân în stocarea securizată și nu sunt scrise în fișierele de backup.';

  @override
  String get restoreBackupFileTitle => 'Restaurează din fișier JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Alege un fișier complet de backup Sked. Vei confirma înainte de restaurare.';

  @override
  String get restoreBackupTextTitle => 'Lipește JSON de backup';

  @override
  String get restoreBackupTextSubtitle =>
      'Lipește un backup complet și restaurează datele curente ale aplicației.';

  @override
  String get shareBackupTitle => 'Partajează fișierul de backup';

  @override
  String get shareBackupSubtitle =>
      'Exportă toate datele aplicației ca JSON. Cheile API sunt excluse.';

  @override
  String get saveBackupTitle => 'Salvează fișierul de backup';

  @override
  String get saveBackupSubtitle =>
      'Salvează un backup complet al aplicației într-un fișier local.';

  @override
  String get copyBackupTitle => 'Copiază textul backupului';

  @override
  String get copyBackupSubtitle =>
      'Afișează JSON-ul complet al backupului, ca să îl poți copia sau păstra temporar.';

  @override
  String get restoreBackupConfirmTitle => 'Restaurezi backupul complet?';

  @override
  String get restoreBackupConfirmMessage =>
      'Aceasta înlocuiește toate orarele, programele generale, setările și site-urile școlare curente. Cheile API nu sunt importate din backupuri; reintrodu cheia înainte de a analiza din nou orare.';

  @override
  String get restoreBackupConfirmAction => 'Restaurează backupul';

  @override
  String get restoreBackupSuccessMessage =>
      'Backupul complet al aplicației a fost restaurat. Cheile AI API trebuie reintroduse.';

  @override
  String get restoreBackupFailureMessage =>
      'Restaurarea a eșuat. Verifică conținutul backupului și încearcă din nou.';

  @override
  String get openSourceLicenses => 'Licențe open-source';

  @override
  String get openSourceLicensesDesc =>
      'Vizualizați licențele pentru dependențele Flutter și activele de pictogramă a aplicației.';

  @override
  String get checkForUpdates => 'Verificați pentru actualizări';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String get microsoftStoreUpdates =>
      'Actualizările sunt gestionate de Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Primește versiuni preliminare';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Include versiunile Alpha, Beta și RC, care pot fi instabile. Când este dezactivat, sunt oferite doar versiuni stabile.';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Deja pe cea mai recentă versiune ($version)';
  }

  @override
  String get currentVersionLabel => 'Versiunea curentă';

  @override
  String get newVersionAvailable => 'Actualizare disponibilă';

  @override
  String get latestVersionLabel => 'Ultima versiune';

  @override
  String get updateContentLabel => 'Detalii de actualizare';

  @override
  String get officialWebsite => 'Site-ul oficial';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Drive în cloud';

  @override
  String get ignoreThisVersion => 'Ignoraţi această versiune';

  @override
  String get openUpdatesFailed => 'Imposibil de deschis link-ul de actualizare';

  @override
  String get updateCheckFailedTitle => 'Verificarea actualizării a eșuat';

  @override
  String get updateCheckFailedMessage =>
      'Nu s-a putut obține cea mai recentă versiune de pe GitHub. Poți deschide GitHub Releases mai jos.';

  @override
  String get githubRepository => 'Repozitoriul GitHub';

  @override
  String get googlePlayStoreDesc => 'Vezi Sked pe Google Play';

  @override
  String get openGooglePlayFailed => 'Nu s-a putut deschide Google Play';

  @override
  String get starSkedOnGithub => 'Oferă o stea pentru Sked pe GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Deschide depozitul proiectului și oferă o stea pentru Sked';

  @override
  String get openGithubFailed =>
      'Imposibil de deschis link-ul de depozit GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Nu s-a putut deschide linkul politicii de confidențialitate';

  @override
  String get selectPeriodTimeSet => 'Alegeți intervalul de timp';

  @override
  String get newItem => 'Nou';

  @override
  String get editPeriodTimeSet => 'Editați intervalul de timp';

  @override
  String get importTimetableFiles => 'Import orar';

  @override
  String get importTimetableFilesDesc =>
      'Suporta unul sau mai multe fișiere de orar.';

  @override
  String get importTimetableText => 'Importarea orarului din text';

  @override
  String get importTimetableTextDesc =>
      'Lipiți conținutul JSON al programului și importați-l.';

  @override
  String get shareTimetableFiles => 'Partajați fișiere de orar';

  @override
  String get shareTimetableFilesDesc =>
      'Alegeți mai întâi unul sau mai multe programe.';

  @override
  String get saveTimetableFiles => 'Salvați fișierele de orar';

  @override
  String get saveTimetableFilesDesc =>
      'Alegeți mai întâi unul sau mai multe programe.';

  @override
  String get exportTimetableText => 'Exportarea orarului ca text';

  @override
  String get exportTimetableTextDesc =>
      'Alegeți unul sau mai multe programe, apoi copiați conținutul JSON.';

  @override
  String get jsonContent => 'Conținut JSON';

  @override
  String get pasteJsonContentHint => 'Lipiți conținutul JSON pentru a importa.';

  @override
  String get jsonContentEmpty => 'Lipiți mai întâi conținutul JSON.';

  @override
  String get copyText => 'Copiați';

  @override
  String get copiedToClipboard => 'Copiat în clipboard';

  @override
  String get share => 'Partajați';

  @override
  String get selectTimetablesToExport => 'Alegeți programele de export';

  @override
  String get selectTimetablesToImport => 'Alegeți programele de import';

  @override
  String timetableCourseCount(int count) {
    return '$count cursuri';
  }

  @override
  String get importAction => 'Importă';

  @override
  String get importTimetableDialogTitle => 'Import orar';

  @override
  String get chooseImportMethod => 'Alegeți cum să importați.';

  @override
  String get importAsNewTimetable => 'Import ca calendar nou';

  @override
  String get replaceCurrentTimetable => 'Înlocuiește orarul curent';

  @override
  String get importPeriodTimeSetDialogTitle =>
      'Seturi de timp pentru perioada de import';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Acest fișier conține seturi de timp de perioadă. Vrei să le importi și să le asociezi?';

  @override
  String get importBundledPeriodTimeSets => 'Import și asociere';

  @override
  String get discardBundledPeriodTimeSets => 'Aruncă seturile în pachet';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Nu este disponibil niciun set de timp de perioadă existent, astfel încât seturile de timp de perioadă combinate nu pot fi aruncate.';

  @override
  String savedToPath(Object path) {
    return 'Salvat în $path';
  }

  @override
  String get saveCancelled => 'Salvare anulată';

  @override
  String get fileSaveRestrictedTitle => 'Salvarea fișierelor restricționată';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Sistemul nu a putut salva fișierul. Puteți încerca din nou sau utilizați partajarea în schimb.';

  @override
  String get retrySave => 'Încercați din nou să salvați';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Activați accesul la fișiere în setările sistemului, apoi întoarceți-vă și încercați din nou să exportați.';

  @override
  String get openSettings => 'Deschide setările';

  @override
  String get browserDownloadRestrictedTitle =>
      'Descărcarea browserului este restricționată';

  @override
  String get browserDownloadRestrictedMessage =>
      'Acest browser nu suportă salvarea directă într-un fișier local. Verificați permisiunile de descărcare ale browserului sau utilizați partajarea fișierelor în schimb.';

  @override
  String get switchToShare => 'Utilizați partajarea în loc';

  @override
  String get fileSaveFailedTitle => 'Salvarea fișierului a eșuat';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Imposibil de scris la calea curentă. Dosarul țintă poate fi protejat, fișierul poate fi în uz sau calea poate fi nescrită.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Sistemul nu a putut salva fișierul. Puteți încerca din nou, verifica setările sistemului sau utilizați partajarea fișierelor în schimb.';

  @override
  String get retryLater => 'Încearcă din nou mai târziu';

  @override
  String get exportSwitchedToShare =>
      'Comutat la partajarea fișierelor pentru export';

  @override
  String get saveFailedRetry =>
      'Salvarea a eșuat. Vă rugăm să încercați din nou mai târziu.';

  @override
  String get periodTimesUnsavedExitTitle => 'Modificări nesalvate';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Ultimele modificări ale orelor de curs nu au putut fi salvate. Poți reîncerca, continua editarea sau renunța la ele.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Unele ore de curs nu sunt valide. Corectează-le înainte de salvare sau renunță la modificări și ieși.';

  @override
  String get discardChangesAndExit => 'Renunță și ieși';

  @override
  String get appInstanceBlockedTitle => 'Sked este deja deschis';

  @override
  String get appInstanceBlockedMessage =>
      'O altă fereastră Sked sau o altă filă de browser folosește datele tale locale. Închide fereastra sau fila respectivă, apoi încearcă din nou.';

  @override
  String get appInstanceLeaseFailedTitle => 'Datele locale nu sunt disponibile';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked nu a putut verifica accesul exclusiv la datele locale. Datele tale nu au fost deschise sau modificate. Verifică accesul la spațiul de stocare, apoi încearcă din nou.';

  @override
  String get savingChanges => 'Se salvează modificările...';

  @override
  String get showApiKey => 'Afișează cheia API';

  @override
  String get hideApiKey => 'Ascunde cheia API';

  @override
  String get importFailedCheckContent =>
      'Importul a eșuat. Vă rugăm să verificați conținutul fișierului.';

  @override
  String get noImportableTimetables =>
      'Nu au fost găsite programe de utilizare în fișierul importat.';

  @override
  String importedTimetablesCount(int count) {
    return 'Importat $count orare';
  }

  @override
  String get periodTimesTitle => 'Perioadele';

  @override
  String get importExport => 'Import și export';

  @override
  String get importPeriodTemplate => 'Şablon de perioadă de import';

  @override
  String get importPeriodTemplateText =>
      'Importarea unui șablon de perioadă din text';

  @override
  String get sharePeriodTemplate => 'Şablon de perioadă de partajare';

  @override
  String get saveTemplateToFile => 'Salvați șablonul în fișier';

  @override
  String get exportPeriodTemplateText =>
      'Exportarea şablonului de perioadă ca text';

  @override
  String get deletePeriodTimeSet => 'Ştergerea intervalului de timp stabilit';

  @override
  String get periodTimeSetName => 'Numele setului de timp pentru perioadă';

  @override
  String get addOnePeriod => 'Adăugați perioadă';

  @override
  String periodNumberLabel(int index) {
    return 'Perioada $index';
  }

  @override
  String get deleteThisPeriod => 'Ștergeți această perioadă';

  @override
  String durationMinutes(int minutes) {
    return 'Durată $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Distanța față de precedentul $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'Ora de sfârșit trebuie să fie mai târziu decât ora de începere';

  @override
  String get periodOverlapPrevious =>
      'Această perioadă se suprapune cu cea precedentă';

  @override
  String get periodTimesSaved => 'Perioadele salvate';

  @override
  String get deletePeriodTimeSetTitle =>
      'Ştergerea intervalului de timp stabilit';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Ştergeţi \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'perioadă curentă de timp stabilit';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Importat $count perioade de timp';
  }

  @override
  String get periodFilePermissionTitle => 'Permisiuni pentru fișiere necesare';

  @override
  String get androidFilePermissionMessage =>
      'Exportul Android necesită permisiunea de acces la fișiere. Acordați permisiunea de a continua să economisiți.';

  @override
  String get reauthorize => 'Autorizează din nou';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Permisiunea refuzată permanent';

  @override
  String get permissionSettingsExportMessage =>
      'Activați accesul la fișiere în setările sistemului, apoi întoarceți-vă și încercați din nou să exportați.';

  @override
  String get privacyPolicyTitle => 'Politica de confidențialitate';

  @override
  String get privacyPolicyEntryDesc =>
      'Aflați cum aplicația gestionează stocarea locală, configurarea site-ului școlii, importul/exportul de fișiere, analizarea paginilor web și linkurile externe.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Versiunea acceptată: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked este un instrument de orar care prioritizează stocarea locală. Orarele, seturile de perioade și configurația site-ului școlii sunt stocate numai pe dispozitivul dvs. sau în browser și nu sunt niciodată încărcate automat. Aplicația procesează datele numai atunci când declanșați explicit acțiuni precum importul, analizarea paginilor web, partajarea sau deschiderea linkurilor externe. Politica de confidențialitate completă este disponibilă online.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Depozitare locală';

  @override
  String get privacyPolicyLocalStorageBody =>
      'Pe platformele native, Sked stochează datele orarului, programele generale, setările asociate și configurația editabilă a site-urilor școlare în directorul de suport al aplicațiilor din sistemul de operare; versiunile pentru browser folosesc stocarea browserului. Fișierele scrise de versiunile anterioare în directorul Documente al utilizatorului rămân acolo, dar nu sunt citite sau migrate automat. Pentru a păstra acele date, exportă o copie de siguranță completă din versiunea veche înainte de actualizare, apoi restaureaz-o. Setările API AI sunt stocate local; cheia API personalizată este stocată prin mecanismul securizat al platformei, când acesta este disponibil. Copiile de siguranță complete nu includ cheia API personalizată. Aplicația nu încarcă automat aceste date locale pe un server controlat de dezvoltator.';

  @override
  String get privacyPolicyImportExportTitle => 'Import și export';

  @override
  String get privacyPolicyImportExportBody =>
      'Aplicația citește sau scrie fișiere JSON de orar, fișiere JSON de site-ul școlii și fișiere de șablon de perioadă numai atunci când alegeți în mod explicit un fișier sau începeți o acțiune de export. Importarea acestor fișiere este o operație locală, cu excepția cazului în care alegeți și analizarea paginilor web. Obținerea unei liste de modele personalizate este, de asemenea, o acțiune de rețea explicită și contactează doar punctul final personalizat pe care l-ați configurat.';

  @override
  String get privacyPolicySharingTitle => 'Partajare';

  @override
  String get privacyPolicySharingBody =>
      'Când utilizați în mod explicit partajarea, aplicația trece fișierul exportat la foaia de partajare a sistemului sau la aplicația țintă pe care o alegeți. Modul în care fișierul este manipulat ulterior depinde de aplicația sau serviciul țintă selectat.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Legături externe';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Când deschideți link-uri externe, cum ar fi depozitul GitHub, aplicația transmite acțiunea browserului sau unei alte aplicații externe. Procesarea datelor după acest punct este guvernată de terța parte pe care o deschideți.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Ce nu colectează aplicația';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Aplicația nu necesită un cont Sked și nu permite analize, identificatori publicitari sau backup în cloud. De asemenea, nu oferă un câmp dedicat colectării parolelor contului școlii. Dacă vă conectați la un site web al școlii în interiorul aplicației, această interacțiune are loc pe pagina școlii pe care ați deschis-o.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Analizarea paginilor web';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Când folosești importul unei pagini web a școlii sau analizezi text de orar / HTML lipit, aplicația pregătește și curăță mai întâi conținutul local, apoi trimite textul de orar, textul paginii sau conținutul HTML trimis, titlul și URL-ul opțional al paginii, limba curentă a aplicației și conținutul promptului parserului către endpointul compatibil OpenAI pe care l-ai configurat. Obținerea listei de modele solicită același endpoint. Sked nu oferă un endpoint de parser integrat și nu trimite cereri de analiză către un backend de parser de orare controlat de dezvoltator. Endpointul personalizat și eventualele servicii upstream pot stoca, redirecționa, limita, șterge sau procesa datele în alt mod conform regulilor furnizorului de servicii ales. Dacă folosești un Base URL http://, utilizează-l numai pe dispozitive, rețele și servicii endpoint de încredere, deoarece conținutul și cheile API pot să nu fie protejate prin criptare de transport.';

  @override
  String get privacyPolicyUpdatesTitle => 'Actualizări ale politicii';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Versiunea actuală a politicii de confidențialitate este $version. Dacă o versiune ulterioară modifică modul în care sunt manipulate datele, aplicația vă poate cere să citiți și să acceptați din nou politica actualizată.';
  }

  @override
  String get privacyGateTitle =>
      'Vă rugăm să acceptați politica de confidențialitate înainte de a utiliza aplicația';

  @override
  String get privacyGateSummaryStorage =>
      'Orarele, seturile de perioade și configurația școlii-site sunt stocate doar local și nu sunt încărcate automat pe un server de dezvoltator.';

  @override
  String get privacyGateSummaryImportExport =>
      'Importul, exportul și partajarea se întâmplă numai atunci când le porniți în mod explicit; analizarea paginilor web trimite doar conținutul comprimat pe care îl trimiteți la punctul final de analizare configurat și puteți revizui programul analizat înainte de a salva.';

  @override
  String get privacyGateSummaryUpdates =>
      'Dacă o versiune ulterioară modifică modul în care sunt manipulate datele, aplicația vă poate cere să revizuiți politica de confidențialitate actualizată din nou.';

  @override
  String get schoolWebImportEntry => 'Import de pe pagina web a școlii';

  @override
  String get schoolWebImportEntryDesc =>
      'Importați pagina de orar curent de pe site-ul școlii.';

  @override
  String get schoolSitesManageEntry => 'Gestionați site-urile școlii';

  @override
  String get schoolSitesManageEntryDesc =>
      'Adăugați, editați și ștergeți URL-urile de conectare la școală, cu import și export JSON.';

  @override
  String get schoolSitesPageTitle => 'Managementul site-ului școlii';

  @override
  String get schoolSitesImportJson => 'Importarea școlii JSON';

  @override
  String get schoolSitesShareJson => 'Partajați școala JSON';

  @override
  String get schoolSitesSaveJson => 'Salvați școala JSON';

  @override
  String get schoolSitesSaved => 'Site-uri școlare salvate';

  @override
  String get schoolSitesImported => 'Site-uri școlare importate';

  @override
  String get schoolSitesImportPreviewTitle =>
      'Verifică importul site-urilor școlare';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount site-uri valide, $invalidCount intrări nevalide.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Fișierul conține o listă goală de site-uri școlare.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Intrarea $position nu este validă și va fi omisă.';
  }

  @override
  String get schoolSitesImportMerge => 'Combină';

  @override
  String get schoolSitesImportReplace => 'Înlocuiește';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Înlocuiești site-urile școlare curente?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Se elimină $currentCount site-uri curente și se salvează $importedCount site-uri importate. Acțiunea nu poate fi anulată.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Datele site-urilor școlare necesită recuperare';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked nu a putut citi fișierul site-urilor școlare sau copia sa de siguranță. Au fost create copii protejate înainte de blocarea scrierii.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Stocarea site-urilor școlare nu este disponibilă';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked nu poate accesa momentan stocarea site-urilor școlare. Verifică accesul la stocare sau disponibilitatea dispozitivului, apoi reîncearcă. Datele curente nu vor fi suprascrise.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Fișierele de recuperare sau locațiile de stocare afectate sunt enumerate mai jos. Păstrează fișierele neschimbate până la recuperarea listei de site-uri.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Începe fără site-uri școlare';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Începi cu o listă goală de site-uri școlare?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Copiile protejate vor fi păstrate, dar Sked va crea un fișier nou și gol pentru site-urile școlare. Continuă doar dacă nu dorești să reîncerci mai întâi recuperarea.';

  @override
  String get schoolSitesEmpty =>
      'Încă nu există configurare a site-ului școlii.';

  @override
  String get schoolSitesNameLabel => 'Numele școlii';

  @override
  String get schoolSitesLoginUrlLabel => 'URL-ul de conectare';

  @override
  String get schoolSitesAdd => 'Adăugați școală';

  @override
  String get schoolSitesEdit => 'Editați școala';

  @override
  String get schoolSitesDeleteTitle => 'Ştergerea şcolii';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Ştergeţi \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Completați mai întâi numele școlii și URL-ul de autentificare.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Import prin lipirea conținutului paginii de orar';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Lipiți manual codul sursă sau conținutul paginii brute care conține informații despre orar.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Analiza programului din conținutul paginii';

  @override
  String get schoolHtmlImportUrlLabel => 'URL sursă (opțional)';

  @override
  String get schoolHtmlImportTitleLabel => 'Titlul paginii (opțional)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Conținutul paginii';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Lipiți codul sursă sau conținutul paginii brute care conține informații despre orar aici.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Orice conținut care conține informații despre orar poate fi analizat și importat, nu doar HTML.';

  @override
  String get schoolHtmlImportCompress => 'Pregătește conținutul';

  @override
  String get schoolHtmlImportCompressed => 'Conținut pregătit';

  @override
  String get schoolHtmlImportCompressFirst => 'Pregătiți mai întâi conținutul.';

  @override
  String get schoolHtmlImportSubmit => 'Analiza și import';

  @override
  String get schoolImportContentTruncated =>
      'Această pagină a atins limita de import sigur. Doar partea capturată va fi trimisă pentru analiză.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Analiza poate dura ceva timp. Vă rog aşteptaţi.';

  @override
  String get schoolHtmlImportEmpty => 'Lipiți mai întâi pagina HTML.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Înapoi la pagina web';

  @override
  String get schoolWebImportPageTitle => 'Importul paginilor web ale școlii';

  @override
  String get schoolWebImportPreview => 'Import previzualizare';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count cursuri';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return ' $count perioade';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Titlul paginii';

  @override
  String get schoolWebImportParserUsed => 'Analizator';

  @override
  String get schoolWebImportWarnings => 'Import de note';

  @override
  String get schoolWebImportParserDetails => 'Detalii de analiză';

  @override
  String get schoolWebImportExpandParserDetails => 'Extinde detaliile analizei';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Restrânge detaliile analizei';

  @override
  String get schoolWebImportOpenPageHint =>
      'Conectați-vă la site-ul școlii în aplicație, apoi navigați manual la pagina de orar.';

  @override
  String get schoolWebImportConfigMissing =>
      'Configurația analizorului personalizat este incompletă. Completează mai întâi URL-ul de bază, cheia API și modelul.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Această platformă nu suportă încă autentificarea web încorporată. Vă rugăm să utilizați o platformă cu suport WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Alegeți școala';

  @override
  String get schoolWebImportNoSchools =>
      'Nu este disponibilă configurația școlii. Verificați mai întâi school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'A eșuat încărcarea configurației școlii. Verificați formatul de fișier JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importează pagina curentă';

  @override
  String get schoolWebImportLoadingPage => 'Se încărcă pagina…';

  @override
  String get schoolWebImportParsing => 'Se analizează pagina curentă...';

  @override
  String get schoolWebImportLoadFailed =>
      'Încărcarea paginii a eșuat. Vă rugăm să vă reîmprospătați sau să încercați din nou mai târziu.';

  @override
  String get schoolWebImportUnknownOrigin => 'Site necunoscut';

  @override
  String get schoolWebImportExitTitle => 'Ieșiți din browser?';

  @override
  String get schoolWebImportExitMessage =>
      'Pagina se va închide. Tot ce nu ați importat încă va fi pierdut.';

  @override
  String get schoolWebImportExitConfirm => 'Ieșire';

  @override
  String get schoolWebImportEmptyPage =>
      'Conținutul paginii curente este gol și nu poate fi încă importat.';

  @override
  String get schoolWebImportSuccess => 'Orarul web importat';

  @override
  String get schoolImportParserSettingsTitle => 'API pentru importul orarului';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configurează API-ul compatibil cu OpenAI pentru importul orarelor, nu pentru un asistent de chat.';

  @override
  String get schoolImportParserSourceTitle => 'Sursa analizatorului';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Compatibil cu OpenAI personalizat';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Parser compatibil cu OpenAI personalizat';

  @override
  String get schoolImportParserCustomPromptTitle => 'Prompt personalizat';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Editați promptul de analizare încorporat aici. Modificările afectează doar analizatorul compatibil cu OpenAI personalizat.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Promptul încorporat este încărcat aici în mod implicit. Eliminați-l pentru a reveni la versiunea încorporată.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Resetați promptul implicit';

  @override
  String get schoolImportParserBaseUrl => 'URL-ul de bază';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL trebuie să fie un URL HTTP sau HTTPS cu gazdă.';

  @override
  String get schoolImportParserApiKey => 'Cheia API';

  @override
  String get schoolImportParserModel => 'Modelul';

  @override
  String get schoolImportParserFetchModels => 'Alege lista modelelor';

  @override
  String get schoolImportParserFetchingModels => 'Aduce modele. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Nu au fost returnate modele de la punctul final.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Modelele nu au putut fi preluate. Verifică endpointul și încearcă din nou.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Modele preluate $count';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'Cheia API personalizată este stocată prin mecanismul securizat al platformei, când acesta este disponibil. Folosește acreditări pentru analizorul personalizat și adrese HTTP doar pe dispozitive, în browsere și în rețele de încredere.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Utilizați un endpoint HTTP necriptat?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'Cheia API și conținutul orarului pot fi citite sau modificate în timpul transferului. Continuați numai dacă aveți încredere în acest dispozitiv, în rețea și în endpoint. Aprobarea este valabilă până când închideți Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Configurarea parserului personalizat este incompletă. Completați mai întâi URL-ul de bază, cheia API și modelul.';

  @override
  String get clearAppData => 'Șterge datele';

  @override
  String get clearAppDataDesc =>
      'Șterge definitiv toate datele locale Sked și închide aplicația';

  @override
  String get clearAppDataConfirmTitle => 'Ștergi toate datele Sked?';

  @override
  String get clearAppDataConfirmMessage =>
      'Această acțiune șterge definitiv orarele, programele, setările, site-urile școlare, copiile de siguranță locale, copiile de recuperare și cheia API AI, apoi închide Sked. Fișierele exportate în alte locații nu sunt șterse. Acțiunea nu poate fi anulată.';

  @override
  String get clearAppDataAction => 'Șterge datele și ieși';

  @override
  String get clearAppDataFailed =>
      'Nu s-au putut șterge toate datele locale. Sked va rămâne deschis pentru a putea reîncerca.';

  @override
  String get clearAppDataExitFailed =>
      'Datele locale au fost șterse, dar Sked nu s-a putut închide. Închide manual aplicația înainte de a o folosi din nou.';

  @override
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'Analizator: Personalizat ($model)';
  }

  @override
  String get privacyViewFullPolicy =>
      'Vezi politica completă de confidențialitate';

  @override
  String get privacyAgreeAndContinue => 'Sunt de acord și continuă';

  @override
  String get privacyDecline => 'Declinează';

  @override
  String get privacyDeclineWebHint =>
      'Acest mediu de browser nu permite aplicației să închidă pagina pentru tine. Dacă nu sunteți de acord, închideți singur această fila sau fereastră.';

  @override
  String get defaultPeriodTimeSetName => 'Perioadele implicite';

  @override
  String get periodTimeSetFallbackName => 'Perioadele';

  @override
  String get untitledTimetableName => 'Orar fără titlu';

  @override
  String get newTimetableName => 'Orar nou';

  @override
  String get newPeriodTimeSetName => 'Noua perioadă de timp stabilită';

  @override
  String get emptyTimetableName => 'Orarul gol';

  @override
  String importedPeriodTimeSetName(Object name) {
    return ' $name perioade';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Tipul de fișier de import nu se potrivește.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Această versiune de fișier de import nu este încă suportată.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Nu s-au găsit vremuri de perioadă în fișierul de import.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Vă rugăm să selectați cel puțin un calendar.';

  @override
  String get noExportableTimetableMessage =>
      'Nu există un calendar disponibil pentru export.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Înlocuirea orarului curent suportă doar selectarea unui singur orar.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Nu există un calendar actual de înlocuit.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Această perioadă de timp este încă utilizată de $count orar(e). Realocați-le înainte de a le șterge.';
  }

  @override
  String get weekdayMonday => 'luni';

  @override
  String get weekdayTuesday => 'Marți';

  @override
  String get weekdayWednesday => 'Miercuri';

  @override
  String get weekdayThursday => 'Joi';

  @override
  String get weekdayFriday => 'vineri';

  @override
  String get weekdaySaturday => 'sâmbătă';

  @override
  String get weekdaySunday => 'Duminică';

  @override
  String get weekdayShortMonday => 'luni';

  @override
  String get weekdayShortTuesday => 'Marți';

  @override
  String get weekdayShortWednesday => 'Miercuri';

  @override
  String get weekdayShortThursday => 'joi';

  @override
  String get weekdayShortFriday => 'vineri';

  @override
  String get weekdayShortSaturday => 'sâmbătă';

  @override
  String get weekdayShortSunday => 'Soarele';

  @override
  String get monthJanuary => 'ianuarie';

  @override
  String get monthFebruary => 'februarie';

  @override
  String get monthMarch => 'martie';

  @override
  String get monthApril => 'Aprilie';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJune => 'iunie';

  @override
  String get monthJuly => 'iulie';

  @override
  String get monthAugust => 'octombrie';

  @override
  String get monthSeptember => 'Septembrie';

  @override
  String get monthOctober => 'octombrie';

  @override
  String get monthNovember => 'noiembrie';

  @override
  String get monthDecember => 'Decembrie';

  @override
  String get semesterWeeksWholeTerm => 'Toate semestrele';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Săptămâni $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Săptămâni $value';
  }

  @override
  String get generalSchedule => 'Program general';

  @override
  String get studentTimetable => 'Orar școlar';

  @override
  String get firstLaunchTitle => 'Alege modul de pornire';

  @override
  String get firstLaunchSubtitle =>
      'Alege spațiul de lucru pe care îl folosești cel mai des. Poți schimba modul mai târziu.';

  @override
  String get firstLaunchStudentDesc =>
      'Gestionează orare, cursuri, săptămâni, ore de curs și importuri.';

  @override
  String get firstLaunchGeneralDesc =>
      'Gestionează categorii, evenimente, mementouri și date JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Începe cu orarul';

  @override
  String get firstLaunchStartGeneral => 'Începe cu programul';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Alegând un spațiu de lucru inițial, confirmi că ai citit și accepți ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Politica de confidențialitate';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Schimbă modul';

  @override
  String get generalScheduleComingSoon =>
      'Programul general va fi disponibil în curând';

  @override
  String get switchToStudentTimetable => 'Treci la orarul școlar';

  @override
  String get mySchedule => 'Programul meu';

  @override
  String get today => 'Astăzi';

  @override
  String get addEvent => 'Adaugă eveniment';

  @override
  String get editEvent => 'Editează evenimentul';

  @override
  String get eventTitle => 'Titlu';

  @override
  String get eventTitleRequired => 'Titlul este obligatoriu';

  @override
  String get eventStartTime => 'Ora de început';

  @override
  String get eventEndTime => 'Ora de sfârșit';

  @override
  String get eventDate => 'Dată';

  @override
  String get eventTime => 'Oră';

  @override
  String get eventNotes => 'Note';

  @override
  String get eventColor => 'Culoare';

  @override
  String get eventRecurrence => 'Repetare';

  @override
  String get recurrenceNone => 'Nu se repetă';

  @override
  String get recurrenceWeekly => 'Săptămânal';

  @override
  String get recurrenceEndDate => 'Data de sfârșit';

  @override
  String get recurrenceNoEndDate => 'Fără dată de sfârșit';

  @override
  String get recurrenceSetEndDate => 'Setează';

  @override
  String get recurrenceChangeEndDate => 'Schimbă';

  @override
  String get repeatsWeekly => 'Se repetă săptămânal';

  @override
  String recurrenceUntil(Object date) {
    return 'Până la $date';
  }

  @override
  String get switchToGeneralSchedule => 'Treci la programul general';

  @override
  String get generalDisplaySettings => 'Setări generale de afișare';

  @override
  String get generalDisplaySettingsDesc =>
      'Vizualizări, bară de instrumente, formatul datei și adăugare rapidă';

  @override
  String get closePopupOnOutsideTap =>
      'Închide fereastra la atingerea în exterior';

  @override
  String get showGridLines => 'Afișează liniile grilei';

  @override
  String get generalScheduleImportExport => 'Import și export de categorii';

  @override
  String get generalScheduleImportExportDesc =>
      'Importă sau distribuie categoriile programului';

  @override
  String get importGeneralSchedules => 'Importă categorii';

  @override
  String get importGeneralSchedulesDesc =>
      'Citește categorii dintr-un fișier JSON';

  @override
  String get shareGeneralSchedules => 'Distribuie categorii';

  @override
  String get shareGeneralSchedulesDesc => 'Distribuie categorii ca fișier JSON';

  @override
  String get saveGeneralSchedules => 'Salvează categorii';

  @override
  String get saveGeneralSchedulesDesc => 'Salvează categorii ca fișier JSON';

  @override
  String get selectSchedulesToExport => 'Selectează categoriile de exportat';

  @override
  String get selectSchedulesToImport => 'Selectează categoriile de importat';

  @override
  String generalScheduleEventCount(int count) {
    return 'Evenimente: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Categorii importate: $count';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Adaugi importul ca o categorie nouă sau înlocuiești una existentă?';

  @override
  String get addAsNewSchedule => 'Adaugă drept categorie nouă';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Selectează cel puțin o categorie.';

  @override
  String get noExportableScheduleMessage => 'Nu există categorii de exportat.';

  @override
  String get noSchedulesInImportMessage =>
      'Fișierul de import nu conține categorii.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Selectează exact o categorie importată pentru înlocuire.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Categoria selectată pentru înlocuire nu este disponibilă.';

  @override
  String get calendars => 'Categorii';

  @override
  String get calendar => 'Categorie';

  @override
  String get viewWeek => 'Săptămână';

  @override
  String get viewDay => 'Zi';

  @override
  String get viewList => 'Listă';

  @override
  String get viewMonth => 'Lună';

  @override
  String visibleCategoryCount(int count) {
    return 'Categorii: $count';
  }

  @override
  String get noVisibleCategories => 'Nicio categorie vizibilă';

  @override
  String get selectCategoryToReplace => 'Alege categoria de înlocuit';

  @override
  String get replaceCategory => 'Înlocuiește categoria';

  @override
  String get deleteEventTitle => 'Șterge evenimentul';

  @override
  String get deleteEventConfirmation =>
      'Acest eveniment va fi șters definitiv.';

  @override
  String get deleteRecurringEventTitle => 'Șterge evenimentul recurent';

  @override
  String get eventDuplicated => 'Eveniment duplicat';

  @override
  String get searchEvents => 'Caută evenimente';

  @override
  String get clearSearch => 'Golește căutarea';

  @override
  String get filterByColor => 'Filtrează după culoare';

  @override
  String get allColors => 'Toate culorile';

  @override
  String upcomingEventsCount(int count) {
    return 'Viitoare: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Întârziate: $count';
  }

  @override
  String get allDay => 'Toată ziua';

  @override
  String get collapseAllDayTimeline =>
      'Restrânge evenimentele de o zi întreagă';

  @override
  String get expandAllDayTimeline => 'Extinde evenimentele de o zi întreagă';

  @override
  String allDayEventsCount(int count) {
    return 'Evenimente de o zi întreagă: $count';
  }

  @override
  String moreEvents(int count) {
    return '+$count în plus';
  }

  @override
  String get noMatchingEvents => 'Niciun eveniment potrivit';

  @override
  String get noUpcomingEvents => 'Niciun eveniment viitor';

  @override
  String get addCalendar => 'Adaugă categorie';

  @override
  String get newCalendar => 'Categorie nouă';

  @override
  String get hideCalendar => 'Ascunde categoria';

  @override
  String get showCalendar => 'Afișează categoria';

  @override
  String get rename => 'Redenumește';

  @override
  String get renameCalendar => 'Redenumește categoria';

  @override
  String get name => 'Nume';

  @override
  String get deleteCalendar => 'Șterge categoria';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Ștergi „$name”?';
  }

  @override
  String get deleteThisOccurrence => 'Șterge această apariție';

  @override
  String get deleteFutureOccurrences =>
      'Șterge această apariție și următoarele';

  @override
  String get deleteAllOccurrences => 'Șterge întreaga serie';

  @override
  String get duplicateEvent => 'Duplică';

  @override
  String get repeatsDaily => 'Se repetă zilnic';

  @override
  String get repeatsMonthly => 'Se repetă lunar';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Interval ($unit): $interval';
  }

  @override
  String recurrenceCountTimes(int count) {
    return 'Repetări: $count';
  }

  @override
  String get recurrenceDaily => 'Zilnic';

  @override
  String get recurrenceMonthly => 'Lunar';

  @override
  String get recurrenceCustom => 'Personalizat';

  @override
  String get recurrenceEvery => 'La fiecare';

  @override
  String get recurrenceUnit => 'Unitate';

  @override
  String get recurrenceDays => 'zile';

  @override
  String get recurrenceWeeks => 'săptămâni';

  @override
  String get recurrenceMonths => 'luni';

  @override
  String get recurrenceRepeatCount => 'Număr de repetări';

  @override
  String get recurrenceNoLimit => 'Fără limită';

  @override
  String get recurrencePositiveNumber => 'Introdu un număr pozitiv';

  @override
  String get clearEndDate => 'Șterge data de sfârșit';

  @override
  String get pickDate => 'Alege data';

  @override
  String get pickTime => 'Alege ora';

  @override
  String get reminder => 'Memento în aplicație';

  @override
  String get reminderAtStart => 'La început';

  @override
  String reminderMinutesBefore(int minutes) {
    return 'Cu $minutes min înainte';
  }

  @override
  String get reminderHourBefore => 'Cu 1 oră înainte';

  @override
  String get reminderDayBefore => 'Cu 1 zi înainte';

  @override
  String get markReminderHandled => 'Marchează ca tratat';

  @override
  String get restoreReminder => 'Restabilește mementoul în aplicație';

  @override
  String get reminderHandled => 'Memento în aplicație marcat ca tratat';

  @override
  String get reminderRestored => 'Memento în aplicație restabilit';

  @override
  String get reminderUpcoming => 'Viitor';

  @override
  String get reminderOverdue => 'Întârziat';

  @override
  String get generalFitWeekColumnsToWidth => 'Potrivește săptămâna pe ecran';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Afișează întreaga săptămână în aspectele compacte. Dezactivează pentru derulare orizontală. Intervalele personalizate de peste 7 zile rămân derulabile.';

  @override
  String get showWeekends => 'Afișează weekendurile';

  @override
  String get startHour => 'Ora de început';

  @override
  String get endHour => 'Ora de sfârșit';

  @override
  String get timeGridDensity => 'Densitatea grilei de timp';

  @override
  String get timeGridHourHeight => 'Înălțimea rândului unei ore';

  @override
  String get timeGridHourHeightHint =>
      'Ajustează scara verticală a vizualizărilor de zi și săptămână fără a schimba intervalul grilei de 15, 30 sau 60 de minute.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Importă fișier JSON';

  @override
  String get pasteJson => 'Lipește JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Importă categorii din JSON copiat';

  @override
  String get importIcsFile => 'Importă fișier ICS';

  @override
  String get importIcsFileDesc =>
      'Citește evenimente dintr-un fișier de calendar .ics';

  @override
  String get pasteIcs => 'Lipește ICS';

  @override
  String get pasteIcsDesc => 'Importă evenimente din textul de calendar copiat';

  @override
  String get copyJson => 'Copiază JSON';

  @override
  String get copyJsonDesc => 'Copiază categoriile selectate ca text JSON';

  @override
  String get shareIcs => 'Distribuie ICS';

  @override
  String get shareIcsDesc => 'Distribuie calendarele selectate ca .ics';

  @override
  String get saveIcs => 'Salvează ICS';

  @override
  String get saveIcsDesc => 'Salvează calendarele selectate ca .ics';

  @override
  String get copyIcs => 'Copiază ICS';

  @override
  String get copyIcsDesc => 'Copiază calendarele selectate ca text ICS';

  @override
  String get importIcs => 'Importă ICS';

  @override
  String get icsContent => 'Conținut ICS';

  @override
  String get pasteIcsContentHint => 'Lipește aici conținutul BEGIN:VCALENDAR';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Evenimente găsite: $count. Le adaugi într-o categorie nouă sau înlocuiești una existentă?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Categorii importate: $count; avertismente: $warningCount';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'S-a omis un eveniment fără oră de început.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'S-a omis un eveniment cu oră de început neacceptată.';

  @override
  String get importWarningAdjustedEnd =>
      'S-a ajustat un eveniment al cărui sfârșit nu era după început.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Câmpurile ICS neacceptate au fost adăugate la note: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'S-a ignorat frecvența de repetare neacceptată: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Selectează calendarele de copiat ca ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Selectează calendarele de exportat ca ICS';

  @override
  String get exportIcsText => 'Exportă text ICS';

  @override
  String get exportJsonText => 'Exportă text JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Datele aplicației au fost restaurate din copia de siguranță anterioară, deoarece fișierul principal nu s-a putut încărca.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Atât fișierul principal de date, cât și copia sa de siguranță sunt deteriorate. Aplicația folosește acum o stare inițială nouă.';

  @override
  String get dataRecoveryCorruptTitle => 'Datele tale necesită recuperare';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked nu a putut citi fișierul principal de date sau copia sa de siguranță. Au fost create copii protejate înainte de blocarea scrierii.';

  @override
  String get dataRecoveryIoFailureTitle => 'Stocarea nu este disponibilă';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked nu poate accesa momentan stocarea locală. Verifică accesul la stocare sau disponibilitatea dispozitivului, apoi reîncearcă. Datele existente nu vor fi suprascrise.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Actualizează Sked pentru a deschide aceste date';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Aceste date au fost create de o versiune mai nouă de Sked. Actualizează aplicația înainte de a reîncerca. Pornirea de la zero este dezactivată pentru a proteja datele.';

  @override
  String get dataRecoveryRetryAction => 'Reîncearcă';

  @override
  String get dataRecoveryArtifactsHint =>
      'Fișierele de recuperare sau locațiile de stocare afectate sunt enumerate mai jos. Păstrează fișierele neschimbate până la recuperarea datelor.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Afișează fișierele și locațiile de recuperare';

  @override
  String get dataRecoveryStartFreshAction => 'Începe cu date noi';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Începi cu date noi?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Copiile protejate vor fi păstrate, dar Sked va crea un fișier local de date nou. Continuă doar dacă nu dorești să reîncerci mai întâi recuperarea.';

  @override
  String get previousMonth => 'Luna precedentă';

  @override
  String get nextMonth => 'Luna următoare';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'În desfășurare';

  @override
  String get deleteCourseTitle => 'Șterge cursul';

  @override
  String get deleteCourseMessage => 'Ștergi acest curs?';

  @override
  String get showLunarCalendar => 'Afișează calendarul lunar';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, evenimente: $count';
  }

  @override
  String get defaultView => 'Vizualizare implicită';

  @override
  String get generalDefaultViewSection => 'La pornire';

  @override
  String get generalViewSwitchBehavior => 'Buton de schimbare a vizualizării';

  @override
  String get settingsWorkspaceMode => 'Spațiu de lucru activ';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Ascunde navigarea spațiilor de lucru';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Ascunde navigarea spațiilor de lucru. Le poți schimba în continuare din meniul ecranului principal.';

  @override
  String get generalDateLabelFormat => 'Formatul etichetei de dată';

  @override
  String get generalDateLabelFormatLocalized => 'Localizat (iul. 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Cu bară oblică (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Aspectul barei de instrumente';

  @override
  String get toolbarNavigationSection => 'Navigarea barei de instrumente';

  @override
  String get toolbarNavigationHiddenBehavior => 'Elemente ascunse';

  @override
  String get toolbarNavigationRemove => 'Ascunde complet';

  @override
  String get toolbarNavigationMore => 'Mută în Mai multe';

  @override
  String get toolbarNavigationReorder => 'Reordonează elementele barei';

  @override
  String get toolbarNavigationVisibility => 'Afișează elementul barei';

  @override
  String get toolbarNavigationTimetable => 'Selector de orar';

  @override
  String get toolbarNavigationWeek => 'Selector de săptămână';

  @override
  String get toolbarNavigationView => 'Comutator de vizualizare';

  @override
  String get toolbarNavigationCategory => 'Selector de categorie';

  @override
  String get toolbarNavigationDate => 'Selector de dată';

  @override
  String get generalToolbarWidthPolicy => 'Alocarea spațiului barei';

  @override
  String get generalToolbarWidthContent => 'Alocare automată';

  @override
  String get generalToolbarWidthBalanced => 'Echilibrat';

  @override
  String get generalToolbarWidthCalendarPriority =>
      'Prioritate pentru categorie';

  @override
  String get generalToolbarWidthDatePriority => 'Prioritate pentru dată';

  @override
  String get generalViewSwitchCycle => 'Parcurge vizualizările';

  @override
  String get generalViewSwitchMenu => 'Deschide meniul de vizualizare';

  @override
  String get generalViewSwitchTooltip => 'Schimbă vizualizarea';

  @override
  String get generalViewSwitchMenuTooltip => 'Alege vizualizarea';

  @override
  String get generalViewLongPressTodayHint =>
      'Apasă lung pentru a merge la ziua de azi';

  @override
  String get generalScheduleDisplaySection => 'Afișarea programului';

  @override
  String get generalTimeGridSection => 'Grilă de timp';

  @override
  String get generalPopupSection => 'Comportamentul ferestrei pop-up';

  @override
  String get quickActionsSection => 'Acțiuni rapide';

  @override
  String get showAddCourseFab =>
      'Afișează butonul flotant de adăugare a cursurilor';

  @override
  String get showAddCourseFabHint =>
      'Afișează sau ascunde butonul flotant de adăugare a cursurilor din colțul din dreapta jos al orarului.';

  @override
  String get showAddEventFab =>
      'Afișează butonul flotant de adăugare a evenimentelor';

  @override
  String get showAddEventFabHint =>
      'Afișează sau ascunde butonul flotant de adăugare a evenimentelor din colțul din dreapta jos al programului.';

  @override
  String get enableLongPressAddCourse =>
      'Apasă lung pe grila goală pentru a adăuga cursuri';

  @override
  String get enableLongPressAddCourseHint =>
      'Apasă lung pe o zonă goală a grilei orarului pentru a adăuga un curs.';

  @override
  String get enableLongPressAddEvent =>
      'Apasă lung pe grila goală pentru a adăuga evenimente';

  @override
  String get enableLongPressAddEventHint =>
      'În vizualizarea de zi sau săptămână, apasă lung pe o zonă goală a grilei de timp pentru a adăuga un eveniment.';

  @override
  String get developerModeTitle => 'Mod pentru dezvoltatori';

  @override
  String get developerModeDescription =>
      'Instrumente pentru adăugarea unor date demonstrative complete, utile la verificarea aspectului și interacțiunilor.';

  @override
  String get developerSampleLanguage => 'Limba datelor demonstrative';

  @override
  String get developerSampleChinese => 'Chineză';

  @override
  String get developerSampleEnglish => 'Engleză';

  @override
  String get developerSampleDataDescription =>
      'Adaugă un orar și un set de categorii și evenimente fără a înlocui datele existente.';

  @override
  String get developerAddSampleData => 'Adaugă date demonstrative';

  @override
  String get developerSampleDataAdded =>
      'Orarul și evenimentele demonstrative au fost adăugate.';

  @override
  String get developerModeLongPressHint =>
      'Țineți apăsat timp de 3 secunde pentru a deschide modul pentru dezvoltatori';

  @override
  String get developerNotificationDiagnostics => 'Diagnosticarea notificărilor';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Verifică starea livrării pe Android, reconstruiește planul existent de mementouri și trimite notificări de test sigure prin serviciul obișnuit de notificări Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Diagnosticarea notificărilor este disponibilă doar pe Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Diagnosticarea notificărilor este disponibilă după pornirea coordonatorului agendei.';

  @override
  String get developerNotificationRefresh => 'Reîmprospătează diagnosticul';

  @override
  String get developerNotificationSystemStatus =>
      'Permisiunea de notificare a sistemului';

  @override
  String get developerNotificationPermissionAllowed => 'Permisă';

  @override
  String get developerNotificationPermissionBlocked => 'Blocată';

  @override
  String get developerNotificationExactAlarm => 'Alarme exacte';

  @override
  String get developerNotificationExactAlarmAllowed => 'Permise';

  @override
  String get developerNotificationExactAlarmBlocked => 'Nepermise';

  @override
  String get developerNotificationPlan => 'Planul de notificări al agendei';

  @override
  String get developerNotificationCoverage => 'Acoperire';

  @override
  String get developerNotificationCoverageReady =>
      'Toate mementourile cunoscute cu număr finit de repetări sunt programate direct';

  @override
  String get developerNotificationCoverageRenewable =>
      'Mementourile recurente sunt reînnoite în limita posibilităților pentru acoperire pe termen lung';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Capacitatea alarmelor directe este plină; mementourile ulterioare sunt reînnoite în limita posibilităților';

  @override
  String get developerNotificationCoverageBlocked =>
      'Condițiile pentru livrare precisă nu sunt îndeplinite';

  @override
  String get developerNotificationCoverageFailed =>
      'Ultima sincronizare a mementourilor a eșuat';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled alarme directe / capacitate $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled programate, $planned planificate';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Ultima eroare: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Reconstruiește planul de notificări';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Planul de notificări a fost reconstruit.';

  @override
  String get developerNotificationTestChannel => 'Canal de test';

  @override
  String get developerNotificationTestCourse => 'Mementouri pentru cursuri';

  @override
  String get developerNotificationTestSchedule => 'Mementouri pentru program';

  @override
  String get developerNotificationImmediateTest => 'Trimite un test imediat';

  @override
  String get developerNotificationThirtySecondTest =>
      'Programează un test în fundal peste 30 de secunde';

  @override
  String get developerNotificationImmediateQueued =>
      'Notificarea de test imediat a fost trimisă.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Testul în fundal a fost programat peste 30 de secunde.';

  @override
  String get developerNotificationAppSwitch =>
      'Comutatorul mementourilor din aplicație';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Activat pentru mementouri obișnuite';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Dezactivat pentru mementouri obișnuite; testele pentru dezvoltatori pot rula în continuare';

  @override
  String get developerNotificationTimeZone => 'Fus orar local';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Nu a fost creat încă. Un test pentru dezvoltatori îl va crea.';

  @override
  String get developerNotificationChannelEnabledState => 'Activat';

  @override
  String get developerNotificationChannelBlockedState => 'Blocat';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Importanță: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Importanța nu este disponibilă';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending în așteptare / $active active';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Ultima afișare nativă: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Nu s-a înregistrat încă nicio recalculare.';

  @override
  String get developerNotificationNextReminder => 'Următorul memento real';

  @override
  String get developerNotificationNoPendingReminder =>
      'Niciun memento viitor în planul curent';

  @override
  String get developerNotificationNextMaintenance => 'Următoarea întreținere';

  @override
  String get developerNotificationNextRenewal =>
      'Următoarea încercare de reînnoire';

  @override
  String get developerNotificationNoMaintenance => 'Neprogramată';

  @override
  String get developerNotificationTruncation => 'Trunchierea planului';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count omise din cauza limitei planului';
  }

  @override
  String get developerNotificationLastReconciliation => 'Ultima recalculare';

  @override
  String get developerNotificationLastSynchronization =>
      'Ultima sincronizare a mementourilor';

  @override
  String get developerNotificationLateRecovery =>
      'Recuperarea mementourilor întârziate';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count mementouri au fost recuperate după ora inițială';
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
  String get developerNotificationReconcileOriginForeground => 'Prim-plan';

  @override
  String get developerNotificationReconcileOriginBackground => 'Fundal';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Recalculare completă';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Întreținere';

  @override
  String get developerNotificationReconcileModeRecovery => 'Recuperare';

  @override
  String get developerNotificationRunRecovery =>
      'Rulează recuperarea mementourilor';

  @override
  String get developerNotificationRecoveryComplete =>
      'Recuperarea mementourilor s-a încheiat';

  @override
  String get developerNotificationReconcileResultSuccess => 'Reușită';

  @override
  String get developerNotificationReconcileResultSkipped => 'Omisă';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Blocată până la îndeplinirea tuturor condițiilor de livrare precisă';

  @override
  String get developerNotificationReconcileResultFailed => 'Eșuată';

  @override
  String get developerNotificationBackgroundLimits =>
      'Restricții de fundal ale producătorului';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Restricțiile de fundal ale producătorului pot afecta livrarea.';

  @override
  String get developerNotificationAutostart =>
      'Pornire în fundal a producătorului';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Producător: $vendor; este disponibilă o intrare către setările producătorului. Android nu poate afișa starea permisiunii.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Producător: $vendor; se folosesc detaliile aplicației ca alternativă. Android nu poate afișa starea permisiunii.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Nu este disponibilă nicio intrare către setările de fundal ale producătorului.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Ultima destinație deschisă: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'setările producătorului';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'detaliile aplicației';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'niciuna';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Limitele recuperării după repornire';

  @override
  String get developerNotificationRebootBoundary =>
      'Recuperarea începe după prima deblocare; o aplicație oprită forțat nu se poate porni singură.';

  @override
  String get developerNotificationTestChecking =>
      'Testele nu sunt disponibile în timpul verificării stării notificărilor.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Testele nu sunt disponibile deoarece notificările de sistem sunt blocate.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Testele nu sunt disponibile deoarece canalul de notificare selectat este blocat.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Gestionată de setările de notificare Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Nu se aplică pe Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Identitatea pachetului Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Identitate MSIX disponibilă; cardurile active pot fi eliminate';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Instalează versiunea MSIX pentru a elimina fiabil cardurile active';

  @override
  String get collapseWorkspaceNavigation =>
      'Restrânge navigarea spațiului de lucru';

  @override
  String get expandWorkspaceNavigation =>
      'Extinde navigarea spațiului de lucru';

  @override
  String get schoolWebImportExitBrowser => 'Ieși din browserul integrat';

  @override
  String get schoolWebImportEditAddress => 'Editează adresa';

  @override
  String get schoolWebImportAddressLabel => 'Adresă web';

  @override
  String get schoolWebImportOpenAddress => 'Deschide';

  @override
  String get schoolWebImportAddressInvalid =>
      'Introduceți o adresă HTTP sau HTTPS cu o gazdă.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Această pagină web a solicitat o fereastră nouă care nu poate fi deschisă pe acest dispozitiv.';

  @override
  String get schoolWebImportSecureConnection => 'Conexiune securizată';

  @override
  String get schoolWebImportInsecureConnection => 'Conexiune nesecurizată';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Deschideți autentificarea în sistemul școlii?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Autentificarea în sistemul școlii poate trimite date de conectare prin formulare sau redirecționări ale serverului către școală și furnizorii săi de autentificare. Android nu poate întrerupe fiecare astfel de transfer pentru o confirmare separată a destinației. Continuați numai dacă aveți încredere în aceștia pentru această sesiune de import:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Deschideți o autentificare școlară nesecurizată?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Această autentificare școlară folosește HTTP. Oricine poate monitoriza sau modifica această conexiune vă poate citi ori schimba datele de conectare și conținutul paginii. Continuați numai dacă acceptați acest risc pentru:\n\n$origin';
  }

  @override
  String get notificationSettingsSection => 'Mementouri și notificări';

  @override
  String get notificationCoverage => 'Acoperirea mementourilor';

  @override
  String get notificationCoverageRenewable =>
      'Programele recurente fără dată de sfârșit folosesc reînnoirea în fundal pentru acoperire pe termen lung.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android poate păstra direct cel mult $capacity mementouri; cele ulterioare sunt reînnoite din timp, în limita posibilităților.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Activează mementourile și notificările';

  @override
  String get notificationSettingsEnabledHint =>
      'Programează notificări doar pentru elementele cu memento. Setează mai jos un memento implicit pentru cursurile care îl moștenesc.';

  @override
  String get notificationPrecisionLimitations =>
      'Mementourile depind de permisiuni și de rularea în fundal. Oprirea, schimbarea orei sau restricțiile sistemului le pot întârzia.';

  @override
  String get notificationSettingsEnabledSummary => 'Activate';

  @override
  String get notificationSettingsDisabledSummary => 'Dezactivate';

  @override
  String get notificationDefaultsSection => 'Mementouri implicite';

  @override
  String get notificationCourseDefaultReminder =>
      'Memento implicit pentru cursuri';

  @override
  String get notificationGeneralDefaultReminder =>
      'Memento implicit pentru program';

  @override
  String get notificationReminderOff => 'Fără memento';

  @override
  String notificationReminderCustom(int minutes) {
    return 'Cu $minutes min înainte';
  }

  @override
  String get notificationPermission => 'Permisiune de notificare';

  @override
  String get notificationPermissionGranted => 'Permisă de sistem';

  @override
  String get notificationPermissionDenied => 'Blocată de sistem';

  @override
  String get notificationPermissionChecking => 'Se verifică permisiunea…';

  @override
  String get notificationPermissionRequest => 'Solicită permisiunea';

  @override
  String get notificationPermissionOpenSettings =>
      'Deschide setările sistemului';

  @override
  String get notificationPermissionRequestFailed =>
      'Nu s-a putut citi permisiunea de notificare. Reîncearcă.';

  @override
  String get notificationExactAlarm => 'Permisiune pentru alarme exacte';

  @override
  String get notificationExactAlarmAllowed => 'Permisă de sistem';

  @override
  String get notificationExactAlarmRequired =>
      'Necesară pentru ore precise ale mementourilor';

  @override
  String get notificationExactAlarmRequest => 'Permite alarme exacte';

  @override
  String get notificationBatteryOptimization => 'Optimizarea bateriei';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Exceptat de la optimizarea bateriei Android';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Mementourile precise necesită exceptarea de la optimizarea bateriei Android';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Deschide setările de optimizare a bateriei';

  @override
  String get notificationAutostart => 'Pornire în fundal a producătorului';

  @override
  String get notificationAutostartVendorHint =>
      'Permite pornirea automată sau rularea în fundal pentru a restaura mementourile după repornire.';

  @override
  String get notificationAutostartFallbackHint =>
      'Deschide detaliile aplicației Sked și permite rularea în fundal. Android nu poate verifica această setare a producătorului.';

  @override
  String get notificationAutostartUnavailable =>
      'Nu s-a găsit o pagină de setări a producătorului. Verifică manual detaliile aplicației Sked.';

  @override
  String get notificationAutostartRequest =>
      'Deschide setările de fundal ale producătorului';

  @override
  String get notificationAutostartOpenFailed =>
      'Nu s-au putut deschide setările de fundal ale producătorului. Verifică manual detaliile aplicației Sked.';

  @override
  String get notificationLockScreenTitles =>
      'Afișează titlurile pe ecranul de blocare';

  @override
  String get notificationLockScreenTitlesHint =>
      'Când este dezactivat, detaliile notificărilor rămân private pe ecranul de blocare.';

  @override
  String get notificationWidgets => 'Widgeturi pe ecranul de pornire';

  @override
  String get notificationWidgetsDesc =>
      'Reîmprospătează widgeturile Sked și află cum să adaugi unul din lansator.';

  @override
  String get notificationWidgetsDialogTitle => 'Adaugă un widget Sked';

  @override
  String get notificationWidgetsDialogMessage =>
      'În lansatorul dispozitivului, apasă lung pe o zonă goală, alege Widgeturi și adaugă un widget Sked. Widgetul arată următoarele cursuri sau evenimente.';

  @override
  String get notificationWidgetsRefresh => 'Reîmprospătează widgeturile';

  @override
  String get notificationWidgetsRefreshed => 'Widgeturi reîmprospătate';

  @override
  String get notificationPlatformUnsupported =>
      'Această platformă nu oferă notificări native.';

  @override
  String get workspaceFeatures => 'Gestionarea funcțiilor';

  @override
  String get workspaceBoth => 'Orar și agendă';

  @override
  String get workspaceOnlyStudent => 'Doar orar';

  @override
  String get workspaceOnlyGeneral => 'Doar agendă';

  @override
  String get workspaceDisableTitle => 'Dezactivezi acest spațiu de lucru?';

  @override
  String get workspaceDisableMessage =>
      'Datele și preferințele vor fi păstrate. Funcțiile și mementourile se vor opri până îl activezi din nou aici.';

  @override
  String get workspaceEnableHint =>
      'Alege funcțiile pe care le folosești. Cel puțin una trebuie să rămână activă.';

  @override
  String get workspaceLastRequired =>
      'Cel puțin un spațiu de lucru trebuie să rămână activ.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Spațiul de lucru este dezactivat, dar mementourile nu au putut fi eliminate. Reîncearcă recuperarea notificărilor.';

  @override
  String get settingsSearch => 'Caută în setări';

  @override
  String get settingsNoResults => 'Nicio setare corespunzătoare';

  @override
  String get settingsDataPrivacy => 'Date și confidențialitate';

  @override
  String get workspacePreferences => 'Afișare și interacțiune';

  @override
  String get workspaceManage => 'Gestionează';

  @override
  String get selectedDayAgenda => 'Ziua selectată';

  @override
  String get notificationTroubleshooting => 'Permisiuni și depanare';

  @override
  String get settingsConnection => 'Conexiune';

  @override
  String get settingsAdvanced => 'Avansat';

  @override
  String get unsavedChangesMessage =>
      'Ai modificări nesalvate. Le elimini și ieși?';

  @override
  String get backupWorkspaceSelection =>
      'Copia de siguranță completă include datele și selecția spațiilor de lucru activate.';

  @override
  String get assistantLayoutPreview => 'AI · Previzualizare aspect';

  @override
  String get assistantSelectionContext =>
      'Folosește selecția curentă drept context';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Ciornă de mesaj';

  @override
  String get assistantPreviewNoSend =>
      'Doar o previzualizare a aspectului. Nimic nu va fi trimis sau modificat.';

  @override
  String get resizePanel => 'Redimensionează panoul';

  @override
  String get minimizeWindow => 'Minimizează';

  @override
  String get maximizeWindow => 'Maximizează';

  @override
  String get restoreWindow => 'Restabilește fereastra';

  @override
  String get closeWindow => 'Închide fereastra';

  @override
  String get courseSystemReminder => 'Memento de sistem';

  @override
  String courseReminderInherit(String reminder) {
    return 'Folosește valoarea implicită ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Mementourile de sistem sunt dezactivate în setările de notificare. Preferința acestui curs poate fi totuși salvată.';

  @override
  String get courseReminderDefaultOff =>
      'Nu este setat niciun memento implicit pentru cursuri. Alege aici un memento personalizat sau setează unul implicit în setările de notificare.';

  @override
  String get courseReminderDeliveryHint =>
      'Această preferință este salvată împreună cu cursul. Livrarea depinde de permisiunile de notificare ale sistemului și de restricțiile de fundal.';

  @override
  String get courseReminderPermissionUnknown =>
      'Starea notificărilor de sistem nu a fost verificată. Verifică setările de notificare înainte de a te baza pe mementouri.';

  @override
  String get courseReminderMinutesLabel => 'Minute înainte de curs';

  @override
  String get exportAction => 'Exportă';

  @override
  String get datePickerSelectWeek => 'Selectează săptămâna';

  @override
  String get datePickerSelectMonth => 'Selectează luna';

  @override
  String get generalDateLabelFormatDescription =>
      'Se aplică navigării după dată pe desktop și pe ecrane mai mici.';

  @override
  String get dateRangeTitle => 'Alege intervalul de date';

  @override
  String get dateRangeCustom => 'Personalizat';

  @override
  String get dateRangeChooseStart => 'Alege data de început';

  @override
  String get dateRangeChooseEnd => 'Alege data de sfârșit';

  @override
  String get dateRangeLimit =>
      'Selectează între 1 și 14 zile, inclusiv ambele capete.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days zile',
      one: '1 zi',
    );
    return 'Personalizat · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Selectează cu rotițele';

  @override
  String get courseReminderUseDefault => 'Folosește valoarea implicită';

  @override
  String get courseReminderInvalidMinutes =>
      'Introdu un număr întreg de minute, zero sau mai mare.';

  @override
  String get generalCustomColumnWidth =>
      'Lățimea coloanelor în vizualizarea personalizată';

  @override
  String get generalCustomColumnWidthAuto => 'Automată';

  @override
  String get generalCustomColumnWidthManual => 'Lățime minimă';

  @override
  String get generalCustomColumnWidthMinimum => 'Lățime minimă pe zi';

  @override
  String get generalCustomColumnWidthHint =>
      'Toate datele folosesc aceeași lățime minimă. Coloanele umplu spațiul disponibil sau se derulează lateral. Afectează doar vizualizarea personalizată.';

  @override
  String get settingsAppearanceLanguage => 'Aspect și limbă';

  @override
  String get settingsAppearanceDetails => 'Culori și contururi';

  @override
  String get monthNoEvents => 'Niciun eveniment în această zi';

  @override
  String get settingsOverview => 'Prezentare generală';

  @override
  String get settingsThemeTarget => 'Temă pentru';

  @override
  String get settingsColorMode => 'Mod de culoare';

  @override
  String get settingsNotificationPreferences => 'Preferințe pentru mementouri';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Mementouri implicite, permisiuni și fiabilitate';

  @override
  String get settingsFeaturesSummary => 'Spații de lucru și navigare';

  @override
  String get settingsPrivacySummary =>
      'Politica de confidențialitate și ștergerea datelor locale';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ore: $count',
      one: 'Ore: 1',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Oră de curs';

  @override
  String get periodTimesDurationColumn => 'Durată';

  @override
  String get periodTimesGapColumn => 'Pauză';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Se așteaptă salvarea…';

  @override
  String get periodTimesSaveFailed => 'Nesalvat · Salvarea a eșuat';

  @override
  String get periodTimesInvalidStatus =>
      'Nesalvat · Corectează orele evidențiate';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked nu a putut confirma dacă ultima salvare a fost anulată. Scrierea este suspendată, iar copiile de recuperare sunt păstrate. Verificați stocarea și încercați din nou încărcarea.';

  @override
  String get settingsPanelDisplayMode => 'Afișarea panourilor';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Comună pentru orare și calendare';

  @override
  String get settingsPanelDisplayOverlay => 'Suprapus';

  @override
  String get settingsPanelDisplaySideBySide => 'Alăturat';

  @override
  String get settingsPanelDisplayAutomatic => 'Automat';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Suprapune partea dreaptă fără a redimensiona calendarul.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Preferă afișarea alăturată; suprapune doar dacă calendarul devine prea îngust.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Afișează alăturat dacă lățimea calendarului rămâne lizibilă; altfel suprapune.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Dezactivarea Setărilor sau a Spațiului de lucru din bară le mută în Mai multe. Mai multe nu poate fi ascuns cât timp conține acțiuni esențiale. Schimbarea spațiului de lucru apare doar când navigarea de jos este ascunsă și sunt activate mai multe spații de lucru.';

  @override
  String get reminderEnded => 'Încheiat';

  @override
  String get reminderAutoCloseHint =>
      'Se închide după 10 secunde. Interacționează cu panoul pentru a-l păstra deschis.';

  @override
  String get showReminderIndependently => 'Deschide separat';

  @override
  String get categoryManagerTitle => 'Gestionează categoriile';

  @override
  String get categoryHidden => 'Ascunsă';

  @override
  String get categoryShowOnCalendar => 'Afișează în calendar';

  @override
  String get categoryHideOnCalendar => 'Ascunde din calendar';

  @override
  String get categoryEditColor => 'Schimbă culoarea categoriei';

  @override
  String get categoryThemePalette => 'Paleta temei';

  @override
  String get categoryCustomColor => 'Personalizată';

  @override
  String get colorHexInvalid =>
      'Introdu un cod de culoare hexazecimal din șase caractere.';

  @override
  String categoryColorSlot(int number) {
    return 'Culoarea temei $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Actualizările din magazin pot apărea mai târziu. Disponibilitatea este indicată pe pagina magazinului.';

  @override
  String get storePrereleaseNotice =>
      'Primirea notificărilor despre versiuni preliminare nu te înscrie într-un program de testare al magazinului.';

  @override
  String get updateFoundTitle => 'Versiune nouă disponibilă';

  @override
  String get updateNoNotes => 'Nu au fost furnizate note de versiune.';

  @override
  String get updateLater => 'Mai târziu';

  @override
  String get updateRetry => 'Reîncearcă';

  @override
  String get updatePrerelease => 'Versiune preliminară';

  @override
  String get updateNetworkFailure =>
      'Nu s-au putut verifica actualizările. Verifică conexiunea și reîncearcă.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Nu s-a găsit o versiune mai nouă (curentă: $version)';
  }

  @override
  String get backupRestoreInProgressTitle =>
      'Se restaurează copia de siguranță…';

  @override
  String get backupRestoreInProgressMessage =>
      'Datele și setările pot fi modificate după încheierea restaurării. Le poți consulta în continuare.';
}
