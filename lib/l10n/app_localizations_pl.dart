// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Sked';

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
  String get schoolImportExpandWarnings => 'Rozwiń ostrzeżenia importu';

  @override
  String get schoolImportCollapseWarnings => 'Zwiń ostrzeżenia importu';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Niektóre kursy trwają do $week. tygodnia.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Zastąpić bieżący plan zajęć?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Importowany plan zajęć zastąpi bieżący plan.';

  @override
  String get createTimetable => 'Nowy harmonogram';

  @override
  String get jumpToWeek => 'Skocz do tygodnia';

  @override
  String get timetable => 'Rozkład pracy';

  @override
  String get themeWorkspaceSchedule => 'Kalendarz';

  @override
  String get timetableName => 'Nazwa rozkładu';

  @override
  String get timetableNameRequired => 'Nazwa planu zajęć jest wymagana';

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
  String get customFieldsInvalidJson =>
      'Wpisz prawidłowy obiekt JSON lub wyczyść pole.';

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
  String get settingsSectionTimetable => 'Plan zajęć';

  @override
  String get settingsSectionGeneralSchedule => 'Kalendarz ogólny';

  @override
  String get settingsSectionAppearance => 'Wygląd';

  @override
  String get settingsSectionApp => 'Aplikacja';

  @override
  String get settingsSectionWorkspace => 'Obszar roboczy';

  @override
  String get settingsSectionAppearanceLanguage => 'Wygląd i język';

  @override
  String get settingsSectionDataSecurity => 'Dane i bezpieczeństwo';

  @override
  String get settingsSectionAbout => 'O Sked';

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
  String get timetableHorizontalLayoutSection => 'Układ poziomy i gesty';

  @override
  String get fitDaySelectorToWidth => 'Dopasuj wybór dnia do ekranu';

  @override
  String get fitDaySelectorToWidthHint =>
      'W miarę możliwości pokazuje wszystkie siedem dni na ekranie. Wyłącz, aby użyć stałej szerokości i przewijania.';

  @override
  String get fitWeekColumnsToWidth => 'Dopasuj kolumny tygodnia do ekranu';

  @override
  String get fitWeekColumnsToWidthHint =>
      'W miarę możliwości pokazuje wszystkie siedem kolumn planu na ekranie. Wyłącz, aby użyć stałej szerokości i przewijania.';

  @override
  String get enableWeekSwipeNavigation => 'Zmieniaj tygodnie przesunięciem';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Przesuń w lewo lub w prawo, aby zmienić tydzień. Przy stałej szerokości najpierw przeciągnij poza krawędź.';

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
  String get outlineWidthUnit => 'px';

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
  String get microsoftStoreUpdates => 'Aktualizacjami zarządza Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Otrzymuj wersje przedpremierowe';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Uwzględniaj wersje Alpha, Beta i RC, które mogą być niestabilne. Po wyłączeniu oferowane są tylko wersje stabilne.';

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
  String get googlePlay => 'Google Play';

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
      'Nie udało się pobrać najnowszej wersji z GitHuba. Poniżej możesz otworzyć stronę GitHub Releases.';

  @override
  String get githubRepository => 'Repozytorium GitHub';

  @override
  String get googlePlayStoreDesc => 'Zobacz Sked w Google Play';

  @override
  String get openGooglePlayFailed => 'Nie udało się otworzyć Google Play';

  @override
  String get starSkedOnGithub => 'Daj Sked gwiazdkę na GitHubie!';

  @override
  String get starSkedOnGithubDesc =>
      'Otwórz repozytorium projektu i daj Sked gwiazdkę';

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
  String get periodTimesUnsavedExitTitle => 'Zmiany nie zostały zapisane';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Nie udało się zapisać ostatnich zmian godzin lekcji. Możesz ponowić próbę, kontynuować edycję lub odrzucić zmiany.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Niektóre godziny lekcji są nieprawidłowe. Popraw je przed zapisaniem lub odrzuć zmiany i wyjdź.';

  @override
  String get discardChangesAndExit => 'Odrzuć i wyjdź';

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
      'Na platformach natywnych Sked przechowuje plany zajęć, kalendarze ogólne, powiązane ustawienia i edytowalną konfigurację witryn szkół w systemowym katalogu danych aplikacji; wersje przeglądarkowe korzystają z pamięci przeglądarki. Pliki zapisane przez starsze wersje w folderze Dokumenty użytkownika pozostają na miejscu, ale nie są automatycznie odczytywane ani przenoszone. Aby zachować te dane, przed aktualizacją wyeksportuj pełną kopię zapasową ze starej wersji aplikacji, a następnie ją przywróć. Ustawienia API AI są zapisywane lokalnie; niestandardowy klucz API jest przechowywany w bezpiecznym magazynie platformy, jeśli jest dostępny. Pełne kopie zapasowe aplikacji nie zawierają niestandardowego klucza API. Aplikacja nie przesyła automatycznie tych lokalnych danych na serwer zarządzany przez dewelopera.';

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
  String get schoolSitesImportPreviewTitle => 'Sprawdź import witryn szkół';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return 'Prawidłowe witryny: $validCount, nieprawidłowe wpisy: $invalidCount.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Plik zawiera pustą listę witryn szkół.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Wpis $position jest nieprawidłowy i zostanie pominięty.';
  }

  @override
  String get schoolSitesImportMerge => 'Scal';

  @override
  String get schoolSitesImportReplace => 'Zastąp';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Zastąpić bieżące witryny szkół?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Spowoduje to usunięcie $currentCount bieżących witryn i zapisanie $importedCount zaimportowanych witryn. Tej operacji nie można cofnąć.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Dane witryn szkół wymagają odzyskania';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked nie mógł odczytać pliku witryn szkół ani jego kopii zapasowej. Przed zablokowaniem zapisu utworzono chronione kopie.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Pamięć witryn szkół jest niedostępna';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked nie ma teraz dostępu do pamięci witryn szkół. Sprawdź dostęp do pamięci lub dostępność urządzenia i spróbuj ponownie. Bieżące dane witryn nie zostaną nadpisane.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Poniżej wymieniono pliki odzyskiwania lub lokalizacje pamięci, których dotyczy problem. Nie zmieniaj plików do czasu odzyskania listy witryn.';

  @override
  String get schoolSitesRecoveryStartFreshAction => 'Zacznij bez witryn szkół';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Zacząć z pustą listą witryn szkół?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Chronione kopie zostaną zachowane, ale Sked utworzy nowy, pusty plik witryn szkół. Kontynuuj tylko, jeśli nie chcesz najpierw ponowić odzyskiwania.';

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
      'Konfiguracja niestandardowego parsera jest niepełna. Najpierw podaj bazowy URL, klucz API i model.';

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
  String get schoolImportParserSettingsTitle => 'API importu planu zajęć';

  @override
  String get schoolImportParserSettingsDesc =>
      'Skonfiguruj API zgodne z OpenAI do importu planów zajęć, a nie asystenta czatu.';

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
      'Niestandardowy klucz API jest przechowywany w bezpiecznym magazynie platformy, jeśli jest dostępny. Używaj danych logowania niestandardowego parsera i punktów końcowych HTTP tylko na zaufanych urządzeniach, w zaufanych przeglądarkach i sieciach.';

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
  String get clearAppData => 'Wyczyść dane';

  @override
  String get clearAppDataDesc =>
      'Trwale usuń wszystkie lokalne dane Sked i zamknij aplikację';

  @override
  String get clearAppDataConfirmTitle => 'Wyczyścić wszystkie dane Sked?';

  @override
  String get clearAppDataConfirmMessage =>
      'Spowoduje to trwałe usunięcie planów zajęć, kalendarzy, ustawień, witryn szkół, lokalnych kopii zapasowych, kopii odzyskiwania i klucza API AI, a następnie zamknięcie Sked. Pliki wyeksportowane w inne miejsca nie zostaną usunięte. Tej operacji nie można cofnąć.';

  @override
  String get clearAppDataAction => 'Wyczyść dane i wyjdź';

  @override
  String get clearAppDataFailed =>
      'Nie udało się usunąć wszystkich lokalnych danych. Sked pozostanie otwarty, aby umożliwić ponowną próbę.';

  @override
  String get clearAppDataExitFailed =>
      'Dane lokalne zostały usunięte, ale Sked nie mógł się zamknąć. Zamknij aplikację ręcznie przed ponownym użyciem.';

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
  String get generalSchedule => 'Kalendarz ogólny';

  @override
  String get studentTimetable => 'Plan zajęć ucznia';

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
  String get switchMode => 'Zmień tryb';

  @override
  String get generalScheduleComingSoon => 'Kalendarz ogólny już wkrótce';

  @override
  String get switchToStudentTimetable => 'Przełącz na plan zajęć ucznia';

  @override
  String get mySchedule => 'Mój kalendarz';

  @override
  String get today => 'Dzisiaj';

  @override
  String get addEvent => 'Dodaj wydarzenie';

  @override
  String get editEvent => 'Edytuj wydarzenie';

  @override
  String get eventTitle => 'Tytuł';

  @override
  String get eventTitleRequired => 'Tytuł jest wymagany';

  @override
  String get eventStartTime => 'Godzina rozpoczęcia';

  @override
  String get eventEndTime => 'Godzina zakończenia';

  @override
  String get eventDate => 'Data';

  @override
  String get eventTime => 'Godzina';

  @override
  String get eventNotes => 'Notatki';

  @override
  String get eventColor => 'Kolor';

  @override
  String get eventRecurrence => 'Powtarzanie';

  @override
  String get recurrenceNone => 'Nie powtarza się';

  @override
  String get recurrenceWeekly => 'Co tydzień';

  @override
  String get recurrenceEndDate => 'Data zakończenia';

  @override
  String get recurrenceNoEndDate => 'Bez daty zakończenia';

  @override
  String get recurrenceSetEndDate => 'Ustaw';

  @override
  String get recurrenceChangeEndDate => 'Zmień';

  @override
  String get repeatsWeekly => 'Powtarza się co tydzień';

  @override
  String recurrenceUntil(Object date) {
    return 'Do $date';
  }

  @override
  String get switchToGeneralSchedule => 'Przełącz na kalendarz ogólny';

  @override
  String get generalDisplaySettings => 'Ogólne ustawienia wyświetlania';

  @override
  String get generalDisplaySettingsDesc =>
      'Widoki, pasek narzędzi, format daty i szybkie dodawanie';

  @override
  String get closePopupOnOutsideTap => 'Zamykaj okno po dotknięciu poza nim';

  @override
  String get showGridLines => 'Pokaż linie siatki';

  @override
  String get generalScheduleImportExport => 'Import i eksport kategorii';

  @override
  String get generalScheduleImportExportDesc =>
      'Importuj lub udostępniaj kategorie kalendarza';

  @override
  String get importGeneralSchedules => 'Importuj kategorie';

  @override
  String get importGeneralSchedulesDesc => 'Wczytaj kategorie z pliku JSON';

  @override
  String get shareGeneralSchedules => 'Udostępnij kategorie';

  @override
  String get shareGeneralSchedulesDesc => 'Udostępnij kategorie jako plik JSON';

  @override
  String get saveGeneralSchedules => 'Zapisz kategorie';

  @override
  String get saveGeneralSchedulesDesc => 'Zapisz kategorie jako plik JSON';

  @override
  String get selectSchedulesToExport => 'Wybierz kategorie do eksportu';

  @override
  String get selectSchedulesToImport => 'Wybierz kategorie do importu';

  @override
  String generalScheduleEventCount(int count) {
    return 'Wydarzenia: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Zaimportowane kategorie: $count';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Dodać import jako nową kategorię czy zastąpić istniejącą?';

  @override
  String get addAsNewSchedule => 'Dodaj jako nową kategorię';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Wybierz co najmniej jedną kategorię.';

  @override
  String get noExportableScheduleMessage => 'Brak kategorii do eksportu.';

  @override
  String get noSchedulesInImportMessage =>
      'Plik importu nie zawiera kategorii.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Wybierz dokładnie jedną importowaną kategorię do zastąpienia.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Kategoria wybrana do zastąpienia jest niedostępna.';

  @override
  String get calendars => 'Kategorie';

  @override
  String get calendar => 'Kategoria';

  @override
  String get viewWeek => 'Tydzień';

  @override
  String get viewDay => 'Dzień';

  @override
  String get viewList => 'Lista';

  @override
  String get viewMonth => 'Miesiąc';

  @override
  String visibleCategoryCount(int count) {
    return 'Kategorie: $count';
  }

  @override
  String get noVisibleCategories => 'Brak widocznych kategorii';

  @override
  String get selectCategoryToReplace => 'Wybierz kategorię do zastąpienia';

  @override
  String get replaceCategory => 'Zastąp kategorię';

  @override
  String get deleteEventTitle => 'Usuń wydarzenie';

  @override
  String get deleteEventConfirmation =>
      'To wydarzenie zostanie trwale usunięte.';

  @override
  String get deleteRecurringEventTitle => 'Usuń wydarzenie cykliczne';

  @override
  String get eventDuplicated => 'Wydarzenie zduplikowane';

  @override
  String get searchEvents => 'Szukaj wydarzeń';

  @override
  String get clearSearch => 'Wyczyść wyszukiwanie';

  @override
  String get filterByColor => 'Filtruj według koloru';

  @override
  String get allColors => 'Wszystkie kolory';

  @override
  String upcomingEventsCount(int count) {
    return 'Nadchodzące: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Zaległe: $count';
  }

  @override
  String get allDay => 'Całodniowe';

  @override
  String get collapseAllDayTimeline => 'Zwiń wydarzenia całodniowe';

  @override
  String get expandAllDayTimeline => 'Rozwiń wydarzenia całodniowe';

  @override
  String allDayEventsCount(int count) {
    return 'Wydarzenia całodniowe: $count';
  }

  @override
  String moreEvents(int count) {
    return '+$count więcej';
  }

  @override
  String get noMatchingEvents => 'Brak pasujących wydarzeń';

  @override
  String get noUpcomingEvents => 'Brak nadchodzących wydarzeń';

  @override
  String get addCalendar => 'Dodaj kategorię';

  @override
  String get newCalendar => 'Nowa kategoria';

  @override
  String get hideCalendar => 'Ukryj kategorię';

  @override
  String get showCalendar => 'Pokaż kategorię';

  @override
  String get rename => 'Zmień nazwę';

  @override
  String get renameCalendar => 'Zmień nazwę kategorii';

  @override
  String get name => 'Nazwa';

  @override
  String get deleteCalendar => 'Usuń kategorię';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get deleteThisOccurrence => 'Usuń to wystąpienie';

  @override
  String get deleteFutureOccurrences => 'Usuń to i kolejne';

  @override
  String get deleteAllOccurrences => 'Usuń całą serię';

  @override
  String get duplicateEvent => 'Duplikuj';

  @override
  String get repeatsDaily => 'Powtarza się codziennie';

  @override
  String get repeatsMonthly => 'Powtarza się co miesiąc';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Odstęp ($unit): $interval';
  }

  @override
  String recurrenceCountTimes(int count) {
    return 'Liczba powtórzeń: $count';
  }

  @override
  String get recurrenceDaily => 'Codziennie';

  @override
  String get recurrenceMonthly => 'Co miesiąc';

  @override
  String get recurrenceCustom => 'Niestandardowe';

  @override
  String get recurrenceEvery => 'Co';

  @override
  String get recurrenceUnit => 'Jednostka';

  @override
  String get recurrenceDays => 'dni';

  @override
  String get recurrenceWeeks => 'tygodnie';

  @override
  String get recurrenceMonths => 'miesiące';

  @override
  String get recurrenceRepeatCount => 'Liczba powtórzeń';

  @override
  String get recurrenceNoLimit => 'Bez ograniczeń';

  @override
  String get recurrencePositiveNumber => 'Wpisz liczbę dodatnią';

  @override
  String get clearEndDate => 'Usuń datę zakończenia';

  @override
  String get pickDate => 'Wybierz datę';

  @override
  String get pickTime => 'Wybierz godzinę';

  @override
  String get reminder => 'Przypomnienie w aplikacji';

  @override
  String get reminderAtStart => 'Na początku';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min wcześniej';
  }

  @override
  String get reminderHourBefore => '1 godzinę wcześniej';

  @override
  String get reminderDayBefore => '1 dzień wcześniej';

  @override
  String get markReminderHandled => 'Oznacz jako obsłużone';

  @override
  String get restoreReminder => 'Przywróć przypomnienie w aplikacji';

  @override
  String get reminderHandled =>
      'Przypomnienie w aplikacji oznaczono jako obsłużone';

  @override
  String get reminderRestored => 'Przypomnienie w aplikacji przywrócono';

  @override
  String get reminderUpcoming => 'Nadchodzące';

  @override
  String get reminderOverdue => 'Zaległe';

  @override
  String get generalFitWeekColumnsToWidth => 'Dopasuj widok tygodnia do ekranu';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Pokaż cały tydzień w układach kompaktowych. Wyłącz, aby przewijać poziomo. Własne zakresy ponad 7 dni nadal można przewijać.';

  @override
  String get showWeekends => 'Pokaż weekendy';

  @override
  String get startHour => 'Godzina początkowa';

  @override
  String get endHour => 'Godzina końcowa';

  @override
  String get timeGridDensity => 'Gęstość siatki czasu';

  @override
  String get timeGridHourHeight => 'Wysokość wiersza godziny';

  @override
  String get timeGridHourHeightHint =>
      'Dostosowuje skalę pionową widoków dnia i tygodnia bez zmiany odstępu siatki wynoszącego 15, 30 lub 60 minut.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Importuj plik JSON';

  @override
  String get pasteJson => 'Wklej JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Importuj kategorie ze skopiowanego JSON';

  @override
  String get importIcsFile => 'Importuj plik ICS';

  @override
  String get importIcsFileDesc => 'Wczytaj wydarzenia z pliku kalendarza .ics';

  @override
  String get pasteIcs => 'Wklej ICS';

  @override
  String get pasteIcsDesc =>
      'Importuj wydarzenia ze skopiowanego tekstu kalendarza';

  @override
  String get copyJson => 'Kopiuj JSON';

  @override
  String get copyJsonDesc => 'Kopiuj wybrane kategorie jako tekst JSON';

  @override
  String get shareIcs => 'Udostępnij ICS';

  @override
  String get shareIcsDesc => 'Udostępnij wybrane kalendarze jako .ics';

  @override
  String get saveIcs => 'Zapisz ICS';

  @override
  String get saveIcsDesc => 'Zapisz wybrane kalendarze jako .ics';

  @override
  String get copyIcs => 'Kopiuj ICS';

  @override
  String get copyIcsDesc => 'Kopiuj wybrane kalendarze jako tekst ICS';

  @override
  String get importIcs => 'Importuj ICS';

  @override
  String get icsContent => 'Zawartość ICS';

  @override
  String get pasteIcsContentHint => 'Wklej tutaj zawartość BEGIN:VCALENDAR';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Znalezione wydarzenia: $count. Dodać je jako nową kategorię czy zastąpić istniejącą?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Zaimportowane kategorie: $count; ostrzeżenia: $warningCount';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Pominięto wydarzenie bez godziny rozpoczęcia.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Pominięto wydarzenie z nieobsługiwaną godziną rozpoczęcia.';

  @override
  String get importWarningAdjustedEnd =>
      'Poprawiono wydarzenie, którego koniec nie przypadał po rozpoczęciu.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Nieobsługiwane pola ICS dodano do notatek: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Zignorowano nieobsługiwaną częstotliwość powtarzania: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Wybierz kalendarze do skopiowania jako ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Wybierz kalendarze do eksportu jako ICS';

  @override
  String get exportIcsText => 'Eksportuj tekst ICS';

  @override
  String get exportJsonText => 'Eksportuj tekst JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Dane aplikacji przywrócono z poprzedniej kopii zapasowej, ponieważ nie udało się wczytać głównego pliku.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Główny plik danych i jego kopia zapasowa są uszkodzone. Aplikacja korzysta teraz z nowego stanu początkowego.';

  @override
  String get dataRecoveryCorruptTitle => 'Dane wymagają odzyskania';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked nie mógł odczytać głównego pliku danych ani jego kopii zapasowej. Przed zablokowaniem zapisu utworzono chronione kopie.';

  @override
  String get dataRecoveryIoFailureTitle => 'Pamięć jest niedostępna';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked nie ma teraz dostępu do pamięci lokalnej. Sprawdź dostęp do pamięci lub dostępność urządzenia i spróbuj ponownie. Istniejące dane nie zostaną nadpisane.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Zaktualizuj Sked, aby otworzyć te dane';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Te dane utworzono w nowszej wersji Sked. Zaktualizuj aplikację przed ponowną próbą. Rozpoczęcie od nowa jest wyłączone, aby chronić dane.';

  @override
  String get dataRecoveryRetryAction => 'Spróbuj ponownie';

  @override
  String get dataRecoveryArtifactsHint =>
      'Poniżej wymieniono pliki odzyskiwania lub lokalizacje pamięci, których dotyczy problem. Nie zmieniaj plików do czasu odzyskania danych.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Pokaż pliki i lokalizacje odzyskiwania';

  @override
  String get dataRecoveryStartFreshAction => 'Zacznij z nowymi danymi';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Zacząć z nowymi danymi?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Chronione kopie zostaną zachowane, ale Sked utworzy nowy lokalny plik danych. Kontynuuj tylko, jeśli nie chcesz najpierw ponowić odzyskiwania.';

  @override
  String get previousMonth => 'Poprzedni miesiąc';

  @override
  String get nextMonth => 'Następny miesiąc';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'W trakcie';

  @override
  String get deleteCourseTitle => 'Usuń kurs';

  @override
  String get deleteCourseMessage => 'Usunąć ten kurs?';

  @override
  String get showLunarCalendar => 'Pokaż kalendarz księżycowy';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, wydarzenia: $count';
  }

  @override
  String get defaultView => 'Widok domyślny';

  @override
  String get generalDefaultViewSection => 'Uruchamianie';

  @override
  String get generalViewSwitchBehavior => 'Przycisk zmiany widoku';

  @override
  String get settingsWorkspaceMode => 'Aktywny obszar roboczy';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Ukryj nawigację obszarów roboczych';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Ukryj nawigację obszarów roboczych. Nadal możesz je przełączać w menu na ekranie głównym.';

  @override
  String get generalDateLabelFormat => 'Format etykiety daty';

  @override
  String get generalDateLabelFormatLocalized => 'Lokalny (lip 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Z ukośnikiem (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Układ paska narzędzi';

  @override
  String get toolbarNavigationSection => 'Nawigacja paska narzędzi';

  @override
  String get toolbarNavigationHiddenBehavior => 'Ukryte elementy';

  @override
  String get toolbarNavigationRemove => 'Ukryj całkowicie';

  @override
  String get toolbarNavigationMore => 'Przenieś do menu Więcej';

  @override
  String get toolbarNavigationReorder => 'Zmień kolejność elementów paska';

  @override
  String get toolbarNavigationVisibility => 'Pokaż element paska narzędzi';

  @override
  String get toolbarNavigationTimetable => 'Wybór planu zajęć';

  @override
  String get toolbarNavigationWeek => 'Wybór tygodnia';

  @override
  String get toolbarNavigationView => 'Przełącznik widoku';

  @override
  String get toolbarNavigationCategory => 'Wybór kategorii';

  @override
  String get toolbarNavigationDate => 'Wybór daty';

  @override
  String get generalToolbarWidthPolicy => 'Podział miejsca na pasku narzędzi';

  @override
  String get generalToolbarWidthContent => 'Automatyczny podział';

  @override
  String get generalToolbarWidthBalanced => 'Zrównoważony';

  @override
  String get generalToolbarWidthCalendarPriority => 'Priorytet kategorii';

  @override
  String get generalToolbarWidthDatePriority => 'Priorytet daty';

  @override
  String get generalViewSwitchCycle => 'Przełączaj widoki po kolei';

  @override
  String get generalViewSwitchMenu => 'Otwórz menu widoków';

  @override
  String get generalViewSwitchTooltip => 'Zmień widok';

  @override
  String get generalViewSwitchMenuTooltip => 'Wybierz widok';

  @override
  String get generalViewLongPressTodayHint =>
      'Przytrzymaj, aby przejść do dziś';

  @override
  String get generalScheduleDisplaySection => 'Wyświetlanie kalendarza';

  @override
  String get generalTimeGridSection => 'Siatka czasu';

  @override
  String get generalPopupSection => 'Zachowanie okna podręcznego';

  @override
  String get quickActionsSection => 'Szybkie akcje';

  @override
  String get showAddCourseFab => 'Pokaż pływający przycisk dodawania kursu';

  @override
  String get showAddCourseFabHint =>
      'Pokaż lub ukryj pływający przycisk dodawania kursu w prawym dolnym rogu planu zajęć.';

  @override
  String get showAddEventFab => 'Pokaż pływający przycisk dodawania wydarzenia';

  @override
  String get showAddEventFabHint =>
      'Pokaż lub ukryj pływający przycisk dodawania wydarzenia w prawym dolnym rogu kalendarza.';

  @override
  String get enableLongPressAddCourse =>
      'Przytrzymaj pustą siatkę, aby dodać kurs';

  @override
  String get enableLongPressAddCourseHint =>
      'Przytrzymaj pusty obszar siatki planu zajęć, aby dodać kurs.';

  @override
  String get enableLongPressAddEvent =>
      'Przytrzymaj pustą siatkę, aby dodać wydarzenie';

  @override
  String get enableLongPressAddEventHint =>
      'W widoku dnia lub tygodnia przytrzymaj pusty obszar siatki czasu, aby dodać wydarzenie.';

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
  String get developerNotificationDiagnostics => 'Diagnostyka powiadomień';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Sprawdź stan dostarczania w Androidzie, odbuduj istniejący plan przypomnień i wyślij bezpieczne powiadomienia testowe przez standardową usługę powiadomień Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Diagnostyka powiadomień jest dostępna tylko na Androidzie.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Diagnostyka powiadomień będzie dostępna po uruchomieniu koordynatora kalendarza.';

  @override
  String get developerNotificationRefresh => 'Odśwież diagnostykę';

  @override
  String get developerNotificationSystemStatus =>
      'Systemowe uprawnienie do powiadomień';

  @override
  String get developerNotificationPermissionAllowed => 'Dozwolone';

  @override
  String get developerNotificationPermissionBlocked => 'Zablokowane';

  @override
  String get developerNotificationExactAlarm => 'Dokładne alarmy';

  @override
  String get developerNotificationExactAlarmAllowed => 'Dozwolone';

  @override
  String get developerNotificationExactAlarmBlocked => 'Niedozwolone';

  @override
  String get developerNotificationPlan => 'Plan powiadomień kalendarza';

  @override
  String get developerNotificationCoverage => 'Zakres przypomnień';

  @override
  String get developerNotificationCoverageReady =>
      'Wszystkie znane przypomnienia o skończonej liczbie powtórzeń są zaplanowane bezpośrednio';

  @override
  String get developerNotificationCoverageRenewable =>
      'Przypomnienia cykliczne są w miarę możliwości odnawiane, aby zapewnić długoterminowy zakres';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Limit bezpośrednich alarmów został osiągnięty; późniejsze przypomnienia będą odnawiane w miarę możliwości';

  @override
  String get developerNotificationCoverageBlocked =>
      'Warunki dokładnego dostarczania nie są spełnione';

  @override
  String get developerNotificationCoverageFailed =>
      'Ostatnia synchronizacja przypomnień nie powiodła się';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return 'Bezpośrednie alarmy: $scheduled / limit: $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return 'Zaplanowane w systemie: $scheduled, w planie: $planned';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Ostatni błąd: $message';
  }

  @override
  String get developerNotificationRunMaintenance => 'Odbuduj plan powiadomień';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Plan powiadomień został odbudowany.';

  @override
  String get developerNotificationTestChannel => 'Kanał testowy';

  @override
  String get developerNotificationTestCourse => 'Przypomnienia o kursach';

  @override
  String get developerNotificationTestSchedule => 'Przypomnienia kalendarza';

  @override
  String get developerNotificationImmediateTest => 'Wyślij test natychmiast';

  @override
  String get developerNotificationThirtySecondTest =>
      'Zaplanuj test w tle za 30 sekund';

  @override
  String get developerNotificationImmediateQueued =>
      'Natychmiastowe powiadomienie testowe wysłano.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Test w tle zaplanowano za 30 sekund.';

  @override
  String get developerNotificationAppSwitch =>
      'Przełącznik przypomnień w aplikacji';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Zwykłe przypomnienia włączone';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Zwykłe przypomnienia wyłączone; testy deweloperskie nadal mogą działać';

  @override
  String get developerNotificationTimeZone => 'Lokalna strefa czasowa';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Jeszcze nie utworzono. Test deweloperski go utworzy.';

  @override
  String get developerNotificationChannelEnabledState => 'Włączony';

  @override
  String get developerNotificationChannelBlockedState => 'Zablokowany';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Ważność: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Ważność niedostępna';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return 'Oczekujące: $pending / aktywne: $active';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Ostatnio wyświetlone przez system: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Nie zarejestrowano jeszcze przeliczenia.';

  @override
  String get developerNotificationNextReminder =>
      'Następne rzeczywiste przypomnienie';

  @override
  String get developerNotificationNoPendingReminder =>
      'Brak przyszłych przypomnień w bieżącym planie';

  @override
  String get developerNotificationNextMaintenance => 'Następna konserwacja';

  @override
  String get developerNotificationNextRenewal => 'Następna próba odnowienia';

  @override
  String get developerNotificationNoMaintenance => 'Nie zaplanowano';

  @override
  String get developerNotificationTruncation => 'Ograniczenie planu';

  @override
  String developerNotificationTruncationCount(int count) {
    return 'Pominięto z powodu limitu planu: $count';
  }

  @override
  String get developerNotificationLastReconciliation => 'Ostatnie przeliczenie';

  @override
  String get developerNotificationLastSynchronization =>
      'Ostatnia synchronizacja przypomnień';

  @override
  String get developerNotificationLateRecovery =>
      'Odzyskiwanie spóźnionych przypomnień';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return 'Odzyskane przypomnienia po pierwotnym terminie: $count';
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
  String get developerNotificationReconcileOriginForeground => 'Pierwszy plan';

  @override
  String get developerNotificationReconcileOriginBackground => 'Tło';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Pełne przeliczenie';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Konserwacja';

  @override
  String get developerNotificationReconcileModeRecovery => 'Odzyskiwanie';

  @override
  String get developerNotificationRunRecovery =>
      'Uruchom odzyskiwanie przypomnień';

  @override
  String get developerNotificationRecoveryComplete =>
      'Odzyskiwanie przypomnień zakończone';

  @override
  String get developerNotificationReconcileResultSuccess => 'Powodzenie';

  @override
  String get developerNotificationReconcileResultSkipped => 'Pominięto';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Zablokowane do spełnienia wszystkich warunków dokładnego dostarczania';

  @override
  String get developerNotificationReconcileResultFailed => 'Niepowodzenie';

  @override
  String get developerNotificationBackgroundLimits =>
      'Ograniczenia pracy w tle producenta';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Ograniczenia pracy w tle narzucone przez producenta mogą wpływać na dostarczanie.';

  @override
  String get developerNotificationAutostart => 'Uruchamianie w tle producenta';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Producent: $vendor; dostępny jest skrót do jego ustawień. Android nie udostępnia stanu tego uprawnienia.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Producent: $vendor; używany jest zastępczy ekran informacji o aplikacji. Android nie udostępnia stanu tego uprawnienia.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Brak skrótu do ustawień pracy w tle producenta.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Ostatnio otwarty ekran: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'ustawienia producenta';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'informacje o aplikacji';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'brak';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Ograniczenia odzyskiwania po restarcie';

  @override
  String get developerNotificationRebootBoundary =>
      'Odzyskiwanie zaczyna się po pierwszym odblokowaniu; aplikacja zatrzymana wymuszeniem nie może uruchomić się sama.';

  @override
  String get developerNotificationTestChecking =>
      'Testy są niedostępne podczas sprawdzania stanu powiadomień.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Testy są niedostępne, ponieważ powiadomienia systemowe są zablokowane.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Testy są niedostępne, ponieważ wybrany kanał powiadomień jest zablokowany.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Zarządzane przez ustawienia powiadomień Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Nie dotyczy Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Tożsamość pakietu Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Tożsamość MSIX dostępna; aktywne karty powiadomień można usunąć';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Zainstaluj wersję MSIX, aby niezawodnie usuwać aktywne karty powiadomień';

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
  String get notificationSettingsSection => 'Przypomnienia i powiadomienia';

  @override
  String get notificationCoverage => 'Zakres przypomnień';

  @override
  String get notificationCoverageRenewable =>
      'Wydarzenia cykliczne bez daty zakończenia korzystają z odnawiania w tle, aby utrzymać przypomnienia na dłuższy czas.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android może bezpośrednio przechowywać maksymalnie $capacity przypomnień; aplikacja próbuje odnawiać późniejsze z wyprzedzeniem.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Włącz przypomnienia i powiadomienia';

  @override
  String get notificationSettingsEnabledHint =>
      'Planuje powiadomienia tylko dla elementów z przypomnieniem. Poniżej ustaw domyślne przypomnienie dla kursów, które je dziedziczą.';

  @override
  String get notificationPrecisionLimitations =>
      'Przypomnienia zależą od uprawnień systemowych i działania w tle. Wyłączenie, zmiany czasu lub ograniczenia systemu mogą je opóźnić.';

  @override
  String get notificationSettingsEnabledSummary => 'Włączone';

  @override
  String get notificationSettingsDisabledSummary => 'Wyłączone';

  @override
  String get notificationDefaultsSection => 'Domyślne przypomnienia';

  @override
  String get notificationCourseDefaultReminder =>
      'Domyślne przypomnienie o kursie';

  @override
  String get notificationGeneralDefaultReminder =>
      'Domyślne przypomnienie kalendarza';

  @override
  String get notificationReminderOff => 'Bez przypomnienia';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes min wcześniej';
  }

  @override
  String get notificationPermission => 'Uprawnienie do powiadomień';

  @override
  String get notificationPermissionGranted => 'Dozwolone przez system';

  @override
  String get notificationPermissionDenied => 'Zablokowane przez system';

  @override
  String get notificationPermissionChecking => 'Sprawdzanie uprawnienia…';

  @override
  String get notificationPermissionRequest => 'Poproś o uprawnienie';

  @override
  String get notificationPermissionOpenSettings =>
      'Otwórz ustawienia systemowe';

  @override
  String get notificationPermissionRequestFailed =>
      'Nie udało się odczytać uprawnienia do powiadomień. Spróbuj ponownie.';

  @override
  String get notificationExactAlarm => 'Uprawnienie do dokładnych alarmów';

  @override
  String get notificationExactAlarmAllowed => 'Dozwolone przez system';

  @override
  String get notificationExactAlarmRequired =>
      'Wymagane do dokładnego czasu przypomnień';

  @override
  String get notificationExactAlarmRequest => 'Zezwól na dokładne alarmy';

  @override
  String get notificationBatteryOptimization => 'Optymalizacja baterii';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Wyjątek od optymalizacji baterii Androida przyznany';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Dokładne przypomnienia wymagają wyjątku od optymalizacji baterii Androida';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Otwórz ustawienia optymalizacji baterii';

  @override
  String get notificationAutostart => 'Uruchamianie w tle producenta';

  @override
  String get notificationAutostartVendorHint =>
      'Zezwól na automatyczne uruchamianie lub pracę w tle, aby przypomnienia mogły zostać przywrócone po restarcie.';

  @override
  String get notificationAutostartFallbackHint =>
      'Otwórz informacje o Sked i zezwól na pracę w tle. Android nie może zweryfikować tego ustawienia producenta.';

  @override
  String get notificationAutostartUnavailable =>
      'Nie znaleziono strony ustawień producenta. Sprawdź ręcznie informacje o aplikacji Sked.';

  @override
  String get notificationAutostartRequest =>
      'Otwórz ustawienia pracy w tle producenta';

  @override
  String get notificationAutostartOpenFailed =>
      'Nie udało się otworzyć ustawień pracy w tle producenta. Sprawdź ręcznie informacje o aplikacji Sked.';

  @override
  String get notificationLockScreenTitles => 'Pokaż tytuły na ekranie blokady';

  @override
  String get notificationLockScreenTitlesHint =>
      'Po wyłączeniu szczegóły powiadomień pozostają ukryte na ekranie blokady.';

  @override
  String get notificationWidgets => 'Widżety ekranu głównego';

  @override
  String get notificationWidgetsDesc =>
      'Odśwież widżety Sked i dowiedz się, jak dodać je z ekranu głównego.';

  @override
  String get notificationWidgetsDialogTitle => 'Dodaj widżet Sked';

  @override
  String get notificationWidgetsDialogMessage =>
      'Na ekranie głównym urządzenia przytrzymaj puste miejsce, wybierz Widżety i dodaj widżet Sked. Widżet pokazuje następne zajęcia lub wydarzenia.';

  @override
  String get notificationWidgetsRefresh => 'Odśwież widżety';

  @override
  String get notificationWidgetsRefreshed => 'Widżety odświeżone';

  @override
  String get notificationPlatformUnsupported =>
      'Ta platforma nie zapewnia natywnych powiadomień.';

  @override
  String get workspaceFeatures => 'Zarządzanie funkcjami';

  @override
  String get workspaceBoth => 'Plan zajęć i terminarz';

  @override
  String get workspaceOnlyStudent => 'Tylko plan zajęć';

  @override
  String get workspaceOnlyGeneral => 'Tylko terminarz';

  @override
  String get workspaceDisableTitle => 'Wyłączyć ten obszar roboczy?';

  @override
  String get workspaceDisableMessage =>
      'Dane i ustawienia zostaną zachowane. Funkcje i przypomnienia zostaną wstrzymane do ponownego włączenia obszaru w tym miejscu.';

  @override
  String get workspaceEnableHint =>
      'Wybierz używane funkcje. Co najmniej jedna musi pozostać włączona.';

  @override
  String get workspaceLastRequired =>
      'Co najmniej jeden obszar roboczy musi pozostać włączony.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Obszar roboczy jest wyłączony, ale nie udało się usunąć przypomnień. Ponów odzyskiwanie powiadomień.';

  @override
  String get settingsSearch => 'Szukaj ustawień';

  @override
  String get settingsNoResults => 'Brak pasujących ustawień';

  @override
  String get settingsDataPrivacy => 'Dane i prywatność';

  @override
  String get workspacePreferences => 'Wyświetlanie i obsługa';

  @override
  String get workspaceManage => 'Zarządzaj';

  @override
  String get selectedDayAgenda => 'Wybrany dzień';

  @override
  String get notificationTroubleshooting =>
      'Uprawnienia i rozwiązywanie problemów';

  @override
  String get settingsConnection => 'Połączenie';

  @override
  String get settingsAdvanced => 'Zaawansowane';

  @override
  String get unsavedChangesMessage =>
      'Masz niezapisane zmiany. Odrzucić je i wyjść?';

  @override
  String get backupWorkspaceSelection =>
      'Pełna kopia zapasowa zawiera dane i wybór włączonych obszarów roboczych.';

  @override
  String get assistantLayoutPreview => 'AI · Podgląd układu';

  @override
  String get assistantSelectionContext =>
      'Używa bieżącego zaznaczenia jako kontekstu';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Szkic wiadomości';

  @override
  String get assistantPreviewNoSend =>
      'To tylko podgląd układu. Nic nie zostanie wysłane ani zmienione.';

  @override
  String get resizePanel => 'Zmień rozmiar panelu';

  @override
  String get minimizeWindow => 'Minimalizuj';

  @override
  String get maximizeWindow => 'Maksymalizuj';

  @override
  String get restoreWindow => 'Przywróć okno';

  @override
  String get closeWindow => 'Zamknij okno';

  @override
  String get courseSystemReminder => 'Przypomnienie systemowe';

  @override
  String courseReminderInherit(String reminder) {
    return 'Użyj domyślnego ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Przypomnienia systemowe są wyłączone w ustawieniach powiadomień. Nadal można zapisać tę preferencję kursu.';

  @override
  String get courseReminderDefaultOff =>
      'Nie ustawiono domyślnego przypomnienia o kursie. Wybierz tutaj własne lub ustaw domyślne w ustawieniach powiadomień.';

  @override
  String get courseReminderDeliveryHint =>
      'Ta preferencja jest zapisywana z kursem. Dostarczenie zależy od systemowych uprawnień do powiadomień i ograniczeń pracy w tle.';

  @override
  String get courseReminderPermissionUnknown =>
      'Stan powiadomień systemowych nie został sprawdzony. Sprawdź ustawienia powiadomień, zanim zaczniesz polegać na przypomnieniach.';

  @override
  String get courseReminderMinutesLabel => 'Minuty przed zajęciami';

  @override
  String get exportAction => 'Eksportuj';

  @override
  String get datePickerSelectWeek => 'Wybierz tydzień';

  @override
  String get datePickerSelectMonth => 'Wybierz miesiąc';

  @override
  String get generalDateLabelFormatDescription =>
      'Dotyczy nawigacji według dat na komputerach i mniejszych ekranach.';

  @override
  String get dateRangeTitle => 'Wybierz zakres dat';

  @override
  String get dateRangeCustom => 'Niestandardowy';

  @override
  String get dateRangeChooseStart => 'Wybierz datę początkową';

  @override
  String get dateRangeChooseEnd => 'Wybierz datę końcową';

  @override
  String get dateRangeLimit =>
      'Wybierz od 1 do 14 dni, z obiema datami włącznie.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dni',
      one: '1 dzień',
    );
    return 'Niestandardowy · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Wybierz za pomocą pokręteł';

  @override
  String get courseReminderUseDefault => 'Użyj domyślnego';

  @override
  String get courseReminderInvalidMinutes =>
      'Wpisz całkowitą liczbę minut, równą zero lub większą.';

  @override
  String get generalCustomColumnWidth =>
      'Szerokość kolumn w widoku niestandardowym';

  @override
  String get generalCustomColumnWidthAuto => 'Automatyczna';

  @override
  String get generalCustomColumnWidthManual => 'Minimalna szerokość';

  @override
  String get generalCustomColumnWidthMinimum => 'Minimalna szerokość dnia';

  @override
  String get generalCustomColumnWidthHint =>
      'Wszystkie daty mają tę samą minimalną szerokość. Kolumny wypełniają dostępne miejsce lub przewijają się poziomo. Dotyczy tylko widoku niestandardowego.';

  @override
  String get settingsAppearanceLanguage => 'Wygląd i język';

  @override
  String get settingsAppearanceDetails => 'Kolory i kontury';

  @override
  String get monthNoEvents => 'Brak wydarzeń tego dnia';

  @override
  String get settingsOverview => 'Przegląd';

  @override
  String get settingsThemeTarget => 'Motyw dla';

  @override
  String get settingsColorMode => 'Tryb kolorów';

  @override
  String get settingsNotificationPreferences => 'Preferencje przypomnień';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Domyślne przypomnienia, uprawnienia i niezawodność';

  @override
  String get settingsFeaturesSummary => 'Obszary robocze i nawigacja';

  @override
  String get settingsPrivacySummary =>
      'Polityka prywatności i usuwanie danych lokalnych';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lekcje: $count',
      one: 'Lekcje: 1',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Lekcja';

  @override
  String get periodTimesDurationColumn => 'Czas trwania';

  @override
  String get periodTimesGapColumn => 'Przerwa';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Oczekiwanie na zapis…';

  @override
  String get periodTimesSaveFailed => 'Nie zapisano · Zapis nieudany';

  @override
  String get periodTimesInvalidStatus =>
      'Nie zapisano · Popraw zaznaczone godziny';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked nie może potwierdzić, czy ostatni zapis został wycofany. Zapisywanie jest wstrzymane, a kopie odzyskiwania zostały zachowane. Sprawdź pamięć i spróbuj ponownie wczytać dane.';

  @override
  String get settingsPanelDisplayMode => 'Wyświetlanie paneli';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Wspólne dla planów zajęć i kalendarzy';

  @override
  String get settingsPanelDisplayOverlay => 'Nakładka';

  @override
  String get settingsPanelDisplaySideBySide => 'Obok siebie';

  @override
  String get settingsPanelDisplayAutomatic => 'Automatycznie';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Nakłada panel po prawej bez zmiany szerokości kalendarza.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Preferuje układ obok siebie; nakłada panel tylko wtedy, gdy kalendarz byłby zbyt wąski.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Wyświetla obok siebie, jeśli kalendarz pozostaje czytelny; w przeciwnym razie nakłada panel.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Wyłączenie Ustawień lub Obszaru roboczego na pasku przenosi je do menu Więcej. Menu Więcej nie można ukryć, gdy zawiera niezbędne akcje. Przełączanie obszarów roboczych pojawia się tylko przy ukrytej dolnej nawigacji i wielu włączonych obszarach.';

  @override
  String get reminderEnded => 'Zakończone';

  @override
  String get reminderAutoCloseHint =>
      'Zamyka się po 10 sekundach. Użyj panelu, aby pozostał otwarty.';

  @override
  String get showReminderIndependently => 'Otwórz oddzielnie';

  @override
  String get categoryManagerTitle => 'Zarządzaj kategoriami';

  @override
  String get categoryHidden => 'Ukryta';

  @override
  String get categoryShowOnCalendar => 'Pokaż w kalendarzu';

  @override
  String get categoryHideOnCalendar => 'Ukryj w kalendarzu';

  @override
  String get categoryEditColor => 'Zmień kolor kategorii';

  @override
  String get categoryThemePalette => 'Paleta motywu';

  @override
  String get categoryCustomColor => 'Niestandardowy';

  @override
  String get colorHexInvalid => 'Wpisz sześciocyfrowy szesnastkowy kod koloru.';

  @override
  String categoryColorSlot(int number) {
    return 'Kolor motywu $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Aktualizacje w sklepie mogą pojawić się później. O dostępności decyduje strona sklepu.';

  @override
  String get storePrereleaseNotice =>
      'Otrzymywanie powiadomień o wersjach wstępnych nie zapisuje do programu testowego sklepu.';

  @override
  String get updateFoundTitle => 'Dostępna nowa wersja';

  @override
  String get updateNoNotes => 'Nie podano informacji o wydaniu.';

  @override
  String get updateLater => 'Później';

  @override
  String get updateRetry => 'Spróbuj ponownie';

  @override
  String get updatePrerelease => 'Wersja wstępna';

  @override
  String get updateNetworkFailure =>
      'Nie udało się sprawdzić aktualizacji. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Nie znaleziono nowszej wersji (obecna: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Przywracanie kopii zapasowej…';

  @override
  String get backupRestoreInProgressMessage =>
      'Dane i ustawienia będzie można zmieniać po zakończeniu przywracania. Nadal możesz je przeglądać.';
}
