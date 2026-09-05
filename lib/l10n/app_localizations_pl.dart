// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Kolegowie z klasy';

  @override
  String weekLabel(int week) {
    return 'Tydzień $week';
  }

  @override
  String get addCourse => 'Dodaj kurs';

  @override
  String get settings => 'Ustawienia';

  @override
  String get multiTimetableSwitch => 'Przełącz harmonogramy';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Aktualny rozkład · $weeks tygodnie';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Dotknij, aby przełączyć · $weeks tygodnie';
  }

  @override
  String get editTimetable => 'Edytuj harmonogram';

  @override
  String get schoolImportResultEditorTitle => 'Edytuj przeanalizowany wynik';

  @override
  String get schoolImportParsePageTitle => 'Analizuj plan lekcji';

  @override
  String get schoolImportParsePageParsing => 'Analizowanie…';

  @override
  String get schoolImportParsePageFailed => 'Analiza nie powiodła się';

  @override
  String get schoolImportParsePageComplete => 'Analiza ukończona';

  @override
  String get schoolImportParsePageContinue => 'Kontynuuj';

  @override
  String get schoolImportParsePageRawContent => 'Surowa odpowiedź';

  @override
  String get schoolImportParsePageExpandRaw => 'Rozwiń surową odpowiedź';

  @override
  String get schoolImportParsePageCollapseRaw => 'Zwiń surową odpowiedź';

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
  String get createTimetable => 'Nowy harmonogram';

  @override
  String get jumpToWeek => 'Skocz do tygodnia';

  @override
  String get timetable => 'Rozkład pracy';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Nazwa rozkładu';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Całkowita liczba tygodni';

  @override
  String get delete => 'Usuń';

  @override
  String get cancel => 'Anuluj';

  @override
  String get save => 'Zapisz';

  @override
  String get deleteTimetableTitle => 'Usuń harmonogram';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Usuń \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Jeszcze nie ma harmonogramu';

  @override
  String get noTimetableMessage =>
      'Utwórz harmonogram lub zaimportuj go z pliku JSON.';

  @override
  String get importTimetable => 'Import harmonogramu';

  @override
  String get courseName => 'Nazwa kursu';

  @override
  String get location => 'Lokalizacja';

  @override
  String get dayOfWeek => 'Dzień';

  @override
  String get semesterWeeks => 'Tydzień';

  @override
  String get startTime => 'Czas rozpoczęcia';

  @override
  String get endTime => 'Czas końca';

  @override
  String get linkedPeriods => 'Powiązane okresy';

  @override
  String get linkedPeriodsUnmatched =>
      'Żadnych okresów nie pasuje do bieżącego czasu. Dotknij, aby wybrać ręcznie.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Okres $start-$end';
  }

  @override
  String get teacherName => 'Nauczyciel';

  @override
  String get credits => 'Kredyty';

  @override
  String get remarks => 'Uwagi';

  @override
  String get customFields => 'Pole niestandardowe';

  @override
  String get customFieldsHint => 'Jeden na wiersz, format: klucz:wartość';

  @override
  String get more => 'Więcej';

  @override
  String get selectDayOfWeek => 'Wybierz dzień';

  @override
  String get selectSemesterWeeks => 'Wybierz tygodnie';

  @override
  String get selectAll => 'Wybierz wszystkie';

  @override
  String get clear => 'Wyczyść';

  @override
  String get confirm => 'Potwierdź';

  @override
  String get selectLinkedPeriods => 'Wybierz powiązane okresy';

  @override
  String get addCourseTitle => 'Dodaj kurs';

  @override
  String get editCourseTitle => 'Edytuj kurs';

  @override
  String get editCourseTooltip => 'Edytuj kurs';

  @override
  String get place => 'Lokalizacja';

  @override
  String get time => 'Czas';

  @override
  String get notFilled => 'Nie wypełnione';

  @override
  String get none => 'Żaden';

  @override
  String get conflictCourses => 'Konfliktne kursy';

  @override
  String get locationNotFilled => 'Lokalizacja nie wypełniona';

  @override
  String get setAsDisplayed => 'Ustaw jak wyświetlane';

  @override
  String get editThisCourse => 'Edytuj ten kurs';

  @override
  String get settingsTitle => 'Ustawienia';

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
      'Nie ma obecnie dostępnego harmonogramu dla ustawień.';

  @override
  String get semesterStartDate => 'Data rozpoczęcia semestru';

  @override
  String get periodTimeSets => 'Okres ustawienia czasu';

  @override
  String get noPeriodTimeAvailable => 'Brak ustawienia czasu dostępnego okresu';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count okresy';
  }

  @override
  String get coursePopupDismissSetting =>
      'Pozwól na zewnętrzne dotknięcie do zamknięcia wyskakującego okna kursu';

  @override
  String get coursePopupDismissSettingHint =>
      'Wyłączenie tego wyłącza również zwolnienie przesunięciem w dół.';

  @override
  String get preserveTimetableGaps => 'Zachowanie luk w harmonogramie';

  @override
  String get preserveTimetableGapsHint =>
      'Kiedy nie, lunch i przerwa przerwają się, więc późniejsze klasy poruszają się w górę.';

  @override
  String get showPastEndedCourses => 'Pokaż zakończone kursy';

  @override
  String get showPastEndedCoursesHint =>
      'Pokaż kursy, które już zostały zakończone przez prawdziwy bieżący tydzień w jaśniejszym szarym stylu.';

  @override
  String get showFutureCourses => 'Pokaż przyszłe kursy';

  @override
  String get showFutureCoursesHint =>
      'Pokaż kursy, które nie są aktywne w tym tygodniu, ale pojawią się w kolejnych tygodniach w szarym stylu.';

  @override
  String get timetableDisplaySettings =>
      'Wyświetlanie harmonogramu i interakcja';

  @override
  String get timetableDisplaySettingsDesc =>
      'Wyświetlanie zajęć, układ, gesty zmiany tygodnia i szybkie dodawanie';

  @override
  String get showTimetableGridLines => 'Pokaż linie siatki rozkładu';

  @override
  String get showTimetableGridLinesHint =>
      'Kontrola, czy poziome i pionowe linie siatki są widoczne w harmonogramie.';

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
  String get liveCourseOutlineColor => 'Kolor konturu kursu';

  @override
  String get liveCourseOutlineColorHint =>
      'Wybierz, czy kontury są skierowane do bieżącego/następnego kursu lub wszystkich wyświetlanych kursów na bieżącej stronie.';

  @override
  String get liveCourseOutlineSettings => 'Okres kursu';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Konfiguruj, czy kontur jest włączony, na co jest ukierunkowany, czy podąża za kolorem motywu i efektywnym kolorem konturu.';

  @override
  String get liveCourseOutlineEnabled => 'Włącz kontur';

  @override
  String get liveCourseOutlineFollowTheme => 'Śledź kolor tematu';

  @override
  String get liveCourseOutlineTarget => 'Cel nakreślony';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Bieżący/następny kurs';

  @override
  String get liveCourseOutlineTargetAllDisplayed =>
      'Wszystkie wyświetlane kursy';

  @override
  String get liveCourseOutlineEffectiveColor => 'Efektywny kolor';

  @override
  String get liveCourseOutlineCustomColor => 'Niestandardowy kolor konturu';

  @override
  String get liveCourseOutlineWidth => 'Szerokość konturu';

  @override
  String get outlineWidthUnit => 'Px';

  @override
  String get language => 'Język';

  @override
  String get languagePageDescription =>
      'Wybierz jeden z języków, który jest naprawdę dostępny w aplikacji.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'angielski';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Odpowiedź API';

  @override
  String get theme => 'Temat';

  @override
  String get themeFollowSystem => 'Śledź system';

  @override
  String get themeLight => 'Światło';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get themeColor => 'Kolor tematu';

  @override
  String get themeColorModeSingle => 'Kolor pojedynczego motywu';

  @override
  String get themeColorModeColorful => 'Kolorowe';

  @override
  String get themeColorUiColors => 'Kolory interfejsu użytkownika';

  @override
  String get themeColorCourseColors => 'Kolory kursu';

  @override
  String get themeColorPrimary => 'Podstawowe';

  @override
  String get themeColorSecondary => 'Sekundarny';

  @override
  String get themeColorTertiary => 'Terciarne';

  @override
  String get themeColorCourseText => 'Tekst kursu';

  @override
  String get themeColorCourseTextAuto => 'Automatyczny';

  @override
  String get themeColorCourseTextCustom => 'Kolor niestandardowy';

  @override
  String get themeColorCourseColorsEmpty =>
      'Kolory kursu zostaną wygenerowane po importowaniu harmonogramu.';

  @override
  String get themeCustomColor => 'Kolor niestandardowy';

  @override
  String get themeApplyCustomColor => 'Zastosuj kolor';

  @override
  String get themeApplySettings => 'Zastosuj ustawienia';

  @override
  String get dataImportExport => 'Import i eksport danych';

  @override
  String get dataImportExportDesc =>
      'Importuj pełne dane lub pojedyncze harmonogramy lub eksportuj bieżące/wszystkie harmonogramy.';

  @override
  String get appBackupTitle => 'Kopia zapasowa i przywracanie aplikacji';

  @override
  String get appBackupSubtitle =>
      'Twórz kopie lub przywracaj plany lekcji, harmonogramy, ustawienia i strony szkół. Klucze API nie są uwzględniane.';

  @override
  String get appBackupSheetSubtitle =>
      'Pełne przywracanie zastępuje bieżące dane aplikacji. Klucze AI API są w bezpiecznej pamięci i nie są zapisywane w plikach kopii.';

  @override
  String get restoreBackupFileTitle => 'Przywróć z pliku JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Wybierz pełny plik kopii zapasowej Sked. Przed przywróceniem pojawi się prośba o potwierdzenie.';

  @override
  String get restoreBackupTextTitle => 'Wklej JSON kopii';

  @override
  String get restoreBackupTextSubtitle =>
      'Wklej pełną kopię zapasową i przywróć bieżące dane aplikacji.';

  @override
  String get shareBackupTitle => 'Udostępnij plik kopii';

  @override
  String get shareBackupSubtitle =>
      'Eksportuj pełne dane aplikacji jako JSON. Klucze API są pomijane.';

  @override
  String get saveBackupTitle => 'Zapisz plik kopii';

  @override
  String get saveBackupSubtitle =>
      'Zapisz pełną kopię aplikacji w pliku lokalnym.';

  @override
  String get copyBackupTitle => 'Kopiuj tekst kopii';

  @override
  String get copyBackupSubtitle =>
      'Pokaż pełny JSON kopii, aby można go było skopiować lub tymczasowo zapisać.';

  @override
  String get restoreBackupConfirmTitle => 'Przywrócić pełną kopię?';

  @override
  String get restoreBackupConfirmMessage =>
      'To zastąpi wszystkie bieżące plany lekcji, ogólne harmonogramy, ustawienia i strony szkół. Klucze API nie są importowane z kopii; wprowadź klucz ponownie przed kolejnym parsowaniem planów lekcji.';

  @override
  String get restoreBackupConfirmAction => 'Przywróć kopię';

  @override
  String get restoreBackupSuccessMessage =>
      'Pełna kopia aplikacji została przywrócona. Klucze AI API trzeba wprowadzić ponownie.';

  @override
  String get restoreBackupFailureMessage =>
      'Przywracanie nie powiodło się. Sprawdź zawartość kopii i spróbuj ponownie.';

  @override
  String get openSourceLicenses => 'Licencje open source';

  @override
  String get openSourceLicensesDesc =>
      'Zobacz licencje dla zależności Flutter i dołączonych zasobów ikon aplikacji.';

  @override
  String get checkForUpdates => 'Sprawdź aktualizacje';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Już w najnowszej wersji ($version)';
  }

  @override
  String get currentVersionLabel => 'Aktualna wersja';

  @override
  String get newVersionAvailable => 'Dostępna aktualizacja';

  @override
  String get latestVersionLabel => 'Najnowsza wersja';

  @override
  String get updateContentLabel => 'Szczegóły aktualizacji';

  @override
  String get officialWebsite => 'Oficjalna strona internetowa';

  @override
  String get googlePlay => 'w Google Play';

  @override
  String get cloudDrive => 'Napęd w chmurze';

  @override
  String get ignoreThisVersion => 'Ignoruj tę wersję';

  @override
  String get openUpdatesFailed => 'Nie można otworzyć linku do aktualizacji';

  @override
  String get updateCheckFailedTitle => 'Nie udało się sprawdzić aktualizacji';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Repozytorium GitHub';

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
      'Nie można otworzyć linku do repozytorium GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Nie można otworzyć linku do polityki prywatności';

  @override
  String get selectPeriodTimeSet => 'Wybierz ustawienie czasu okresu';

  @override
  String get newItem => 'Nowy';

  @override
  String get editPeriodTimeSet => 'Edytuj ustawienie czasu okresu';

  @override
  String get importTimetableFiles => 'Import harmonogramu';

  @override
  String get importTimetableFilesDesc =>
      'Obsługuje jeden lub więcej plików harmonogramu.';

  @override
  String get importTimetableText => 'Importowanie harmonogramu z tekstu';

  @override
  String get importTimetableTextDesc =>
      'Wklej zawartość harmonogramu JSON i zaimportuj ją.';

  @override
  String get shareTimetableFiles => 'Udostępnij pliki harmonogramu';

  @override
  String get shareTimetableFilesDesc =>
      'Najpierw wybierz jeden lub więcej harmonogramów.';

  @override
  String get saveTimetableFiles => 'Zapisz pliki harmonogramu';

  @override
  String get saveTimetableFilesDesc =>
      'Najpierw wybierz jeden lub więcej harmonogramów.';

  @override
  String get exportTimetableText => 'Eksportowanie harmonogramu jako tekstu';

  @override
  String get exportTimetableTextDesc =>
      'Wybierz jeden lub więcej harmonogramów, a następnie skopiuj zawartość JSON.';

  @override
  String get jsonContent => 'Zawartość JSON';

  @override
  String get pasteJsonContentHint => 'Wklej zawartość JSON do importu.';

  @override
  String get jsonContentEmpty => 'Najpierw wklej zawartość JSON.';

  @override
  String get copyText => 'Kopiowanie';

  @override
  String get copiedToClipboard => 'Skopiowanie do schowka';

  @override
  String get share => 'Udostępnij';

  @override
  String get selectTimetablesToExport => 'Wybierz harmonogram do eksportu';

  @override
  String get selectTimetablesToImport => 'Wybierz harmonogram do importu';

  @override
  String timetableCourseCount(int count) {
    return '$count kursy';
  }

  @override
  String get importAction => 'Importowanie';

  @override
  String get importTimetableDialogTitle => 'Import harmonogramu';

  @override
  String get chooseImportMethod => 'Wybierz sposób importu.';

  @override
  String get importAsNewTimetable => 'Import jako nowy harmonogram';

  @override
  String get replaceCurrentTimetable => 'Zamień bieżący harmonogram';

  @override
  String get importPeriodTimeSetDialogTitle => 'Import zestawów czasu okresu';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Ten plik zawiera zestawy czasu okresu. Chcesz je importować i powiązać?';

  @override
  String get importBundledPeriodTimeSets => 'Import i powiązanie';

  @override
  String get discardBundledPeriodTimeSets => 'Odrzucić zestawy w pakiecie';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Istniejący zestaw czasu okresu nie jest dostępny, dlatego nie można odrzucić zestawów czasu okresu w pakiecie.';

  @override
  String savedToPath(Object path) {
    return 'Zapisane do $path';
  }

  @override
  String get saveCancelled => 'Zapisz anulowane';

  @override
  String get fileSaveRestrictedTitle => 'Zapisywanie plików ograniczone';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'System nie mógł zapisać pliku. Możesz spróbować ponownie lub zamiast tego użyć udostępniania.';

  @override
  String get retrySave => 'Spróbuj ponownie zapisać';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Włącz dostęp do plików w ustawieniach systemu, a następnie wróć i spróbuj ponownie eksportować.';

  @override
  String get openSettings => 'Otwórz ustawienia';

  @override
  String get browserDownloadRestrictedTitle =>
      'Pobieranie przeglądarki ograniczone';

  @override
  String get browserDownloadRestrictedMessage =>
      'Ta przeglądarka nie obsługuje bezpośredniego zapisywania do pliku lokalnego. Sprawdź uprawnienia do pobierania przeglądarki lub zamiast tego użyj udostępniania plików.';

  @override
  String get switchToShare => 'Zamiast tego użyj udostępniania';

  @override
  String get fileSaveFailedTitle => 'Nie udało się zapisać pliku';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Nie można zapisać do bieżącej ścieżki. Folder docelowy może być chroniony, plik może być w użyciu lub ścieżka może nie być zapisywalna.';

  @override
  String get fileSaveFailedGenericMessage =>
      'System nie mógł zapisać pliku. Możesz spróbować ponownie, sprawdzić ustawienia systemu lub zamiast tego użyć udostępniania plików.';

  @override
  String get retryLater => 'Spróbuj ponownie później';

  @override
  String get exportSwitchedToShare =>
      'Przełączono na udostępnianie plików do eksportu';

  @override
  String get saveFailedRetry =>
      'Nie udało się zapisać. Proszę spróbować ponownie później.';

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
  String get appInstanceBlockedTitle => 'Aplikacja Sked jest już otwarta';

  @override
  String get appInstanceBlockedMessage =>
      'Inne okno aplikacji Sked lub karta przeglądarki korzysta z danych lokalnych. Zamknij to okno lub kartę i spróbuj ponownie.';

  @override
  String get appInstanceLeaseFailedTitle => 'Dane lokalne są niedostępne';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked nie mógł potwierdzić wyłącznego dostępu do danych lokalnych. Dane nie zostały otwarte ani zmienione. Sprawdź dostęp do pamięci urządzenia, a następnie spróbuj ponownie.';

  @override
  String get savingChanges => 'Zapisywanie zmian...';

  @override
  String get showApiKey => 'Pokaż klucz API';

  @override
  String get hideApiKey => 'Ukryj klucz API';

  @override
  String get importFailedCheckContent =>
      'Nie udało się importować. Proszę sprawdzić zawartość pliku.';

  @override
  String get noImportableTimetables =>
      'W zaimportowanym pliku nie znaleziono żadnych użytecznych harmonogramów.';

  @override
  String importedTimetablesCount(int count) {
    return 'Importowane harmonogramy $count';
  }

  @override
  String get periodTimesTitle => 'Czasy okresu';

  @override
  String get importExport => 'Import i eksport';

  @override
  String get importPeriodTemplate => 'Szablon okresu importu';

  @override
  String get importPeriodTemplateText =>
      'Importowanie szablonu okresu z tekstu';

  @override
  String get sharePeriodTemplate => 'Szablon okresu udziału';

  @override
  String get saveTemplateToFile => 'Zapisz szablon do pliku';

  @override
  String get exportPeriodTemplateText => 'Eksport szablonu okresu jako tekstu';

  @override
  String get deletePeriodTimeSet => 'Usuń ustawiony czas okresu';

  @override
  String get periodTimeSetName => 'Nazwa zestawu czasu okresu';

  @override
  String get addOnePeriod => 'Dodaj okres';

  @override
  String periodNumberLabel(int index) {
    return 'Okres $index';
  }

  @override
  String get deleteThisPeriod => 'Usuń ten okres';

  @override
  String durationMinutes(int minutes) {
    return 'Czas trwania $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Przerwa od poprzedniego $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'Czas końca musi być później niż czas rozpoczęcia';

  @override
  String get periodOverlapPrevious => 'Ten okres pokrywa się z poprzednim';

  @override
  String get periodTimesSaved => 'Czasy okresowe zapisane';

  @override
  String get deletePeriodTimeSetTitle => 'Usuń ustawiony czas okresu';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Usuń \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'ustawienie czasu bieżącego okresu';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Importowane $count czasy okresu';
  }

  @override
  String get periodFilePermissionTitle => 'Wymagane uprawnienia pliku';

  @override
  String get androidFilePermissionMessage =>
      'Eksport Androida wymaga uprawnień dostępu do plików. Udostępnij pozwolenie na kontynuowanie oszczędzania.';

  @override
  String get reauthorize => 'Autoryzuj ponownie';

  @override
  String get permissionPermanentlyDeniedTitle => 'Pozwolenie trwale odmówione';

  @override
  String get permissionSettingsExportMessage =>
      'Włącz dostęp do plików w ustawieniach systemu, a następnie wróć i spróbuj ponownie eksportować.';

  @override
  String get privacyPolicyTitle => 'Polityka prywatności';

  @override
  String get privacyPolicyEntryDesc =>
      'Dowiedz się, jak aplikacja obsługuje lokalne przechowywanie, konfigurację strony szkolnej, import/eksport plików, analizę stron internetowych i linki zewnętrzne.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Akceptowana wersja: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked to narzędzie do planów lekcji działające lokalnie. Plany lekcji, zestawy okresów i konfiguracja strony szkoły są przechowywane tylko na Twoim urządzeniu lub w przeglądarce i nigdy nie są automatycznie przesyłane. Aplikacja przetwarza dane tylko wtedy, gdy jawnie uruchamiasz działania takie jak import, analiza stron internetowych, udostępnianie lub otwieranie zewnętrznych linków. Pełna polityka prywatności jest dostępna online.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Lokalne przechowywanie';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Import i eksport';

  @override
  String get privacyPolicyImportExportBody =>
      'Aplikacja odczytuje lub pisze pliki JSON harmonogramu, pliki JSON strony szkolnej i pliki szablonu okresu tylko wtedy, gdy wyraźnie wybierzesz plik lub rozpoczniesz akcję eksportu. Importowanie tych plików jest operacją lokalną, chyba że wybierzesz również analizowanie strony internetowej. Pobieranie niestandardowej listy modeli jest również wyraźną akcją sieciową i kontaktuje się tylko z skonfigurowanym przez Ciebie niestandardowym punktem końcowym.';

  @override
  String get privacyPolicySharingTitle => 'Udostępnianie';

  @override
  String get privacyPolicySharingBody =>
      'Kiedy wyraźnie używasz udostępniania, aplikacja przekazuje wyeksportowany plik do arkusza udostępniania systemu lub do wybranej aplikacji docelowej. Jak ten plik jest później obsługiwany zależy od wybranej aplikacji lub usługi docelowej.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Linki zewnętrzne';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Po otwarciu linków zewnętrznych, takich jak repozytorium GitHub, aplikacja przekazuje akcję przeglądarce lub innej aplikacji zewnętrznej. Przetwarzanie danych po tym momencie jest regulowane przez stronę trzecią, którą otwierasz.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Co aplikacja nie zbiera';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Aplikacja nie wymaga konta Sked i nie umożliwia analizy, identyfikatorów reklamowych ani tworzenia kopii zapasowych w chmurze. Nie zapewnia również dedykowanego pola do zbierania haseł do kont szkolnych. Jeśli zalogujesz się do strony internetowej szkoły w aplikacji, ta interakcja odbywa się na stronie szkoły, którą otworzyłeś.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Analiza strony internetowej';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Gdy używasz importu szkolnej strony internetowej albo analizujesz wklejony tekst planu zajęć / HTML, aplikacja najpierw przygotowuje i czyści treść lokalnie, a następnie wysyła przesłany tekst planu, tekst strony lub zawartość HTML, opcjonalny tytuł i URL strony, bieżący język aplikacji oraz treść polecenia parsera do skonfigurowanego przez Ciebie punktu końcowego zgodnego z OpenAI. Pobieranie listy modeli również wysyła żądanie do tego samego punktu końcowego. Sked nie udostępnia wbudowanego punktu końcowego parsera i nie wysyła żądań analizy do backendu parsera planów kontrolowanego przez dewelopera. Niestandardowy punkt końcowy i ewentualne usługi nadrzędne mogą przechowywać, przekazywać, ograniczać, usuwać lub w inny sposób przetwarzać dane zgodnie z zasadami wybranego przez Ciebie dostawcy usług. Jeśli używasz http:// Base URL, korzystaj z niego tylko na zaufanych urządzeniach, w zaufanych sieciach i z zaufanymi usługami punktu końcowego, ponieważ treść i klucze API mogą nie być chronione szyfrowaniem transportowym.';

  @override
  String get privacyPolicyUpdatesTitle => 'Aktualizacje polityki';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Aktualna wersja polityki prywatności to $version. Jeśli w późniejszej wersji zmieni się sposób przetwarzania danych, aplikacja może poprosić Cię o ponowne przeczytanie i zgodę na zaktualizowaną politykę.';
  }

  @override
  String get privacyGateTitle =>
      'Przed użyciem aplikacji zgadzaj się na politykę prywatności';

  @override
  String get privacyGateSummaryStorage =>
      'Rozkłady, zestawy okresów i konfiguracja szkoły są przechowywane tylko lokalnie i nie są automatycznie przesyłane na serwer programistów.';

  @override
  String get privacyGateSummaryImportExport =>
      'Importowanie, eksportowanie i udostępnianie następują tylko wtedy, gdy wyraźnie je uruchomisz; Analiza stron internetowych wysyła tylko skompresowaną zawartość, którą przesyłasz do skonfigurowanego punktu końcowego analizowania, a przed zapisaniem możesz sprawdzić analizowany harmonogram.';

  @override
  String get privacyGateSummaryUpdates =>
      'Jeśli w późniejszej wersji zmieni się sposób przetwarzania danych, aplikacja może poprosić Cię o ponowne zapoznanie się z zaktualizowaną polityką prywatności.';

  @override
  String get schoolWebImportEntry => 'Import ze strony internetowej szkoły';

  @override
  String get schoolWebImportEntryDesc =>
      'Importuj bieżący harmonogram ze strony szkoły.';

  @override
  String get schoolSitesManageEntry => 'Zarządzanie witrynami szkolnymi';

  @override
  String get schoolSitesManageEntryDesc =>
      'Dodaj, edytuj i usuwaj adresy URL logowania szkoły za pomocą importu i eksportu JSON.';

  @override
  String get schoolSitesPageTitle => 'Zarządzanie miejscem szkolnym';

  @override
  String get schoolSitesImportJson => 'Import szkoły JSON';

  @override
  String get schoolSitesShareJson => 'Udostępnij szkołę JSON';

  @override
  String get schoolSitesSaveJson => 'Zapisz szkołę JSON';

  @override
  String get schoolSitesSaved => 'Strony szkolne zapisane';

  @override
  String get schoolSitesImported => 'Miejsca szkolne importowane';

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
  String get schoolSitesEmpty => 'Nie ma jeszcze konfiguracji strony szkolnej.';

  @override
  String get schoolSitesNameLabel => 'Nazwa szkoły';

  @override
  String get schoolSitesLoginUrlLabel => 'URL logowania';

  @override
  String get schoolSitesAdd => 'Dodaj szkołę';

  @override
  String get schoolSitesEdit => 'Edytuj szkołę';

  @override
  String get schoolSitesDeleteTitle => 'Usuń szkołę';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Usuń \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Najpierw wpisz nazwę szkoły i adres URL logowania.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Importowanie przez wklejenie zawartości strony harmonogramu';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Wklej ręcznie kod źródłowy lub surową zawartość strony zawierającą informacje o harmonogramie.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Analizuj harmonogram z zawartości strony';

  @override
  String get schoolHtmlImportUrlLabel => 'URL źródła (opcjonalne)';

  @override
  String get schoolHtmlImportTitleLabel => 'Tytuł strony (opcjonalnie)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Zawartość strony';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Wklej kod źródłowy lub surową zawartość strony zawierającą informacje o harmonogramie tutaj.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Wszystkie treści zawierające informacje o harmonogramie mogą być analizowane i importowane, a nie tylko HTML.';

  @override
  String get schoolHtmlImportCompress => 'Przygotuj treść';

  @override
  String get schoolHtmlImportCompressed => 'Treść przygotowana';

  @override
  String get schoolHtmlImportCompressFirst => 'Najpierw przygotuj treść.';

  @override
  String get schoolHtmlImportSubmit => 'Analizuj i importuj';

  @override
  String get schoolImportContentTruncated =>
      'Ta strona osiągnęła bezpieczny limit importu. Do analizy zostanie wysłana tylko przechwycona część.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Parsing może zająć trochę czasu. Proszę poczekać.';

  @override
  String get schoolHtmlImportEmpty => 'Najpierw wklej stronę HTML.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Powrót do strony internetowej';

  @override
  String get schoolWebImportPageTitle => 'Import strony internetowej szkoły';

  @override
  String get schoolWebImportPreview => 'Importuj podgląd';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count kursy';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return ' $count okresy';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Tytuł strony';

  @override
  String get schoolWebImportParserUsed => 'Parser';

  @override
  String get schoolWebImportWarnings => 'Importuj notatki';

  @override
  String get schoolWebImportParserDetails => 'Szczegóły analizy';

  @override
  String get schoolWebImportExpandParserDetails => 'Rozwiń szczegóły analizy';

  @override
  String get schoolWebImportCollapseParserDetails => 'Zwiń szczegóły analizy';

  @override
  String get schoolWebImportOpenPageHint =>
      'Zaloguj się na stronie szkoły w aplikacji, a następnie przejdź ręcznie do strony harmonogramu.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Ta platforma jeszcze nie obsługuje wbudowanego logowania internetowego. Proszę użyć platformy z obsługą WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Wybierz szkołę';

  @override
  String get schoolWebImportNoSchools =>
      'Nie ma dostępnej konfiguracji szkoły. Najpierw sprawdź school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Nie udało się załadować konfiguracji szkoły. Sprawdź format pliku JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importuj bieżącą stronę';

  @override
  String get schoolWebImportLoadingPage => 'Ładowanie strony…';

  @override
  String get schoolWebImportParsing => 'Analizuje bieżącą stronę...';

  @override
  String get schoolWebImportLoadFailed =>
      'Nie udało się załadować strony. Proszę odświeżyć lub spróbować ponownie później.';

  @override
  String get schoolWebImportUnknownOrigin => 'Nieznana witryna';

  @override
  String get schoolWebImportExitTitle => 'Opuścić przeglądarkę?';

  @override
  String get schoolWebImportExitMessage =>
      'Strona zostanie zamknięta. Wszystko, czego jeszcze nie zaimportowano, zostanie utracone.';

  @override
  String get schoolWebImportExitConfirm => 'Opuść';

  @override
  String get schoolWebImportEmptyPage =>
      'Aktualna zawartość strony jest pusta i nie może być jeszcze zaimportowana.';

  @override
  String get schoolWebImportSuccess => 'Importowany harmonogram internetowy';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Źródło parsera';

  @override
  String get schoolImportParserSourceCustomOpenAi => 'Kompatybilny z OpenAI';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Niestandardowy parser kompatybilny z OpenAI';

  @override
  String get schoolImportParserCustomPromptTitle => 'Niestandardowy prompt';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Edytuj wbudowany prompt parsera tutaj. Zmiany wpływają tylko na niestandardowy parser kompatybilny z OpenAI.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Wbudowany prompt jest domyślnie ładowany tutaj. Wyczyść go, aby wrócić do wbudowanej wersji.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Resetowanie domyślnego promptu';

  @override
  String get schoolImportParserBaseUrl => 'Podstawowy adres URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL musi być adresem HTTP lub HTTPS z hostem.';

  @override
  String get schoolImportParserApiKey => 'Klucz API';

  @override
  String get schoolImportParserModel => 'model';

  @override
  String get schoolImportParserFetchModels => 'Pobierz listę modeli';

  @override
  String get schoolImportParserFetchingModels => 'Zabieranie modeli. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Żadne modele nie zostały zwrócone przez punkt końcowy.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Nie udało się pobrać modeli. Sprawdź punkt końcowy i spróbuj ponownie.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Pobierane modele $count';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Użyć nieszyfrowanego punktu końcowego HTTP?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'Klucz API i zawartość planu lekcji mogą zostać odczytane lub zmienione podczas przesyłania. Kontynuuj tylko wtedy, gdy ufasz temu urządzeniu, sieci i punktowi końcowemu. Zgoda obowiązuje do zamknięcia aplikacji Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Niestandardowa konfiguracja parsera jest niekompletna. Najpierw wypełnij adres URL bazowy, klucz API i model.';

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
    return 'Parser: Niestandardowy ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Zobacz pełną politykę prywatności';

  @override
  String get privacyAgreeAndContinue => 'Zgadzam się i kontynuuj';

  @override
  String get privacyDecline => 'Odrzucić';

  @override
  String get privacyDeclineWebHint =>
      'To środowisko przeglądarki nie pozwala aplikacji na zamknięcie strony za Ciebie. Jeśli nie zgadzasz się, zamknij tę zakładkę lub okno sam.';

  @override
  String get defaultPeriodTimeSetName => 'Domyślne okresy';

  @override
  String get periodTimeSetFallbackName => 'Czasy okresu';

  @override
  String get untitledTimetableName => 'Rozkład bez tytułu';

  @override
  String get newTimetableName => 'Nowy harmonogram';

  @override
  String get newPeriodTimeSetName => 'Ustaw czasu nowego okresu';

  @override
  String get emptyTimetableName => 'Pusty harmonogram';

  @override
  String importedPeriodTimeSetName(Object name) {
    return ' $name okresy';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Typ pliku importowanego nie pasuje.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Ta wersja importu pliku nie jest jeszcze obsługiwana.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Nie znaleziono czasów okresowych w pliku importu.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Proszę wybrać co najmniej jeden harmonogram.';

  @override
  String get noExportableTimetableMessage =>
      'Nie ma dostępnego harmonogramu eksportu.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Zastąpienie bieżącego harmonogramu obsługuje tylko wybór jednego harmonogramu.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Nie ma obecnego harmonogramu do zastąpienia.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Ten zestaw czasu okresu jest nadal używany przez harmonogram $count. Przeznacz je przed usunięciem.';
  }

  @override
  String get weekdayMonday => 'Poniedziałek';

  @override
  String get weekdayTuesday => 'Wtorek';

  @override
  String get weekdayWednesday => 'środa';

  @override
  String get weekdayThursday => 'czwartek';

  @override
  String get weekdayFriday => 'Piątek';

  @override
  String get weekdaySaturday => 'sobota';

  @override
  String get weekdaySunday => 'Niedziela';

  @override
  String get weekdayShortMonday => 'poniedziałek';

  @override
  String get weekdayShortTuesday => 'wtorek';

  @override
  String get weekdayShortWednesday => 'Środa';

  @override
  String get weekdayShortThursday => 'Czwartek';

  @override
  String get weekdayShortFriday => 'Piątek';

  @override
  String get weekdayShortSaturday => 'sobota';

  @override
  String get weekdayShortSunday => 'Słońce';

  @override
  String get monthJanuary => 'stycznia';

  @override
  String get monthFebruary => 'luty';

  @override
  String get monthMarch => 'marzec';

  @override
  String get monthApril => 'kwietnia';

  @override
  String get monthMay => 'maj';

  @override
  String get monthJune => 'czerwca';

  @override
  String get monthJuly => 'lipiec';

  @override
  String get monthAugust => 'sierpień';

  @override
  String get monthSeptember => 'wrzesień';

  @override
  String get monthOctober => 'Październik';

  @override
  String get monthNovember => 'Listopad';

  @override
  String get monthDecember => 'grudzień';

  @override
  String get semesterWeeksWholeTerm => 'Cały semestr';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Tydzień $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Tydzień $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Wybierz tryb początkowy';

  @override
  String get firstLaunchSubtitle =>
      'Wybierz obszar roboczy, którego używasz najczęściej. Tryb możesz później zmienić.';

  @override
  String get firstLaunchStudentDesc =>
      'Zarządzaj planami lekcji, kursami, tygodniami, godzinami lekcji i importem.';

  @override
  String get firstLaunchGeneralDesc =>
      'Zarządzaj kategoriami, wydarzeniami, przypomnieniami oraz danymi JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Zacznij od planu lekcji';

  @override
  String get firstLaunchStartGeneral => 'Zacznij od harmonogramu';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Wybierając początkowy obszar roboczy, potwierdzasz, że znasz i akceptujesz ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Politykę prywatności';

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
  String get today => 'Dzisiaj';

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
      'Widoki, pasek narzędzi, format daty i szybkie dodawanie';

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
  String get viewWeek => 'Tydzień';

  @override
  String get viewDay => 'Dzień';

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
  String get developerModeTitle => 'Tryb deweloperski';

  @override
  String get developerModeDescription =>
      'Narzędzia do dodawania pełnych danych przykładowych w celu sprawdzenia wyglądu i obsługi.';

  @override
  String get developerSampleLanguage => 'Język danych przykładowych';

  @override
  String get developerSampleChinese => 'Chiński';

  @override
  String get developerSampleEnglish => 'Angielski';

  @override
  String get developerSampleDataDescription =>
      'Dodaje jeden plan zajęć oraz zestaw kategorii i wydarzeń bez zastępowania istniejących danych.';

  @override
  String get developerAddSampleData => 'Dodaj dane przykładowe';

  @override
  String get developerSampleDataAdded =>
      'Dodano przykładowy plan zajęć i wydarzenia.';

  @override
  String get developerModeLongPressHint =>
      'Przytrzymaj przez 3 sekundy, aby otworzyć tryb deweloperski';

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
  String get collapseWorkspaceNavigation => 'Zwiń nawigację obszaru roboczego';

  @override
  String get expandWorkspaceNavigation => 'Rozwiń nawigację obszaru roboczego';

  @override
  String get schoolWebImportExitBrowser => 'Zamknij wbudowaną przeglądarkę';

  @override
  String get schoolWebImportEditAddress => 'Edytuj adres';

  @override
  String get schoolWebImportAddressLabel => 'Adres internetowy';

  @override
  String get schoolWebImportOpenAddress => 'Otwórz';

  @override
  String get schoolWebImportAddressInvalid =>
      'Wpisz adres HTTP lub HTTPS z hostem.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Ta strona poprosiła o nowe okno, którego nie można otworzyć na tym urządzeniu.';

  @override
  String get schoolWebImportSecureConnection => 'Bezpieczne połączenie';

  @override
  String get schoolWebImportInsecureConnection => 'Niezabezpieczone połączenie';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Otworzyć logowanie do systemu szkoły?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Logowanie do systemu szkoły może przesyłać dane logowania za pomocą formularzy lub przekierowań serwera do szkoły i jej dostawców logowania. Android nie może wstrzymać każdego takiego transferu, aby osobno potwierdzić miejsce docelowe. Kontynuuj tylko wtedy, gdy ufasz im w tej sesji importu:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Otworzyć niezabezpieczone logowanie do szkoły?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'To logowanie do szkoły używa protokołu HTTP. Każdy, kto może obserwować lub modyfikować to połączenie, może odczytać albo zmienić Twoje dane logowania i zawartość strony. Kontynuuj tylko, jeśli akceptujesz to ryzyko dla:\n\n$origin';
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
