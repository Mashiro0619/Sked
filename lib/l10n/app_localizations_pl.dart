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
  String get schoolImportParseErrorMessage =>
      'Nie udało się przeanalizować planu zajęć. Sprawdź treść, ustawienia parsera i połączenie sieciowe, a następnie spróbuj ponownie.';

  @override
  String get schoolImportParsePageContinue => 'Kontynuuj';

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
  String get timetable => 'Plan zajęć';

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
  String get settingsSectionAppearance => 'Wygląd';

  @override
  String get settingsSectionWorkspace => 'Obszar roboczy';

  @override
  String get settingsSectionAbout => 'O Sked';

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
  String get timetableHorizontalLayoutSection => 'Układ poziomy i gesty';

  @override
  String get fitDaySelectorToWidth => 'Dopasuj wybór dnia do ekranu';

  @override
  String get fitDaySelectorToWidthHint =>
      'W miarę możliwości pokazuje wszystkie siedem dni na ekranie. Wyłącz, aby użyć stałej szerokości i przewijania.';

  @override
  String get fitWeekColumnsToWidth => 'Dopasuj kolumny tygodnia do ekranu';

  @override
  String get enableWeekSwipeNavigation => 'Zmieniaj tygodnie przesunięciem';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Przesuń w lewo lub w prawo, aby zmienić tydzień. Przy stałej szerokości najpierw przeciągnij poza krawędź.';

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
  String get includePrereleaseUpdates => 'Otrzymuj wersje przedpremierowe';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Uwzględniaj wersje Alpha, Beta i RC, które mogą być niestabilne. Po wyłączeniu oferowane są tylko wersje stabilne.';

  @override
  String get currentVersionLabel => 'Aktualna wersja';

  @override
  String get newVersionAvailable => 'Dostępna aktualizacja';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get ignoreThisVersion => 'Ignoruj tę wersję';

  @override
  String get openUpdatesFailed => 'Nie można otworzyć linku do aktualizacji';

  @override
  String get updateCheckFailedTitle => 'Nie udało się sprawdzić aktualizacji';

  @override
  String get githubRepository => 'Repozytorium GitHub';

  @override
  String get googlePlayStoreDesc => 'Zobacz Sked w Google Play';

  @override
  String get openGooglePlayFailed => 'Nie udało się otworzyć Google Play';

  @override
  String get microsoftStoreDesc => 'Zobacz Sked w Microsoft Store';

  @override
  String get openMicrosoftStoreFailed =>
      'Nie udało się otworzyć Microsoft Store';

  @override
  String get starSkedOnGithub => 'Daj Sked gwiazdkę na GitHubie!';

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
  String get studentDayEmpty => 'Brak zajęć w tym dniu';

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
      'Sked to narzędzie do planów zajęć, które stawia na lokalne przechowywanie danych. Plany zajęć, ogólne harmonogramy, zestawy godzin lekcyjnych i konfiguracja stron szkolnych są przechowywane tylko na urządzeniu lub w przeglądarce i nigdy nie są automatycznie przesyłane. Aplikacja przetwarza dane wyłącznie po wyraźnym uruchomieniu takich działań jak import, analiza tekstu / HTML planu zajęć, import szkolnej strony internetowej, udostępnianie lub otwarcie zewnętrznego linku. Pełna polityka prywatności jest dostępna online.';

  @override
  String get privacyGateTitle =>
      'Przed użyciem aplikacji zgadzaj się na politykę prywatności';

  @override
  String get privacyGateSummaryStorage =>
      'Plany zajęć, ogólne harmonogramy, zestawy godzin lekcyjnych i konfiguracja stron szkolnych są przechowywane wyłącznie lokalnie i nie są automatycznie przesyłane na serwer dewelopera.';

  @override
  String get privacyGateSummaryImportExport =>
      'Import, eksport, pełne kopie zapasowe i udostępnianie odbywają się tylko po ich wyraźnym uruchomieniu. Pełne kopie zapasowe aplikacji nie zawierają niestandardowych kluczy API, a analiza tekstu / HTML planu zajęć wysyła wyłącznie przesłaną treść do skonfigurowanego punktu końcowego analizy.';

  @override
  String get privacyGateSummaryUpdates =>
      'Jeśli w późniejszej wersji zmieni się sposób przetwarzania danych, aplikacja może poprosić Cię o ponowne zapoznanie się z zaktualizowaną polityką prywatności.';

  @override
  String get schoolWebImportEntry => 'Import ze strony internetowej szkoły';

  @override
  String get schoolWebImportEntryDesc =>
      'Importuj bieżący harmonogram ze strony szkoły.';

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
  String get schoolWebImportUnsupportedPlatform =>
      'Ta platforma jeszcze nie obsługuje wbudowanego logowania internetowego. Proszę użyć platformy z obsługą WebView.';

  @override
  String get schoolWebImportNoSchools =>
      'Nie ma dostępnej konfiguracji szkoły. Najpierw sprawdź school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Nie udało się wczytać konfiguracji szkoły. Spróbuj ponownie.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importuj bieżącą stronę';

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
  String get importEntryLimitExceededMessage =>
      'This import contains too many entries or overly nested data. Reduce the exported content and try again.';

  @override
  String get confirmImportedStartDatesTitle => 'Confirm semester start dates';

  @override
  String get confirmImportedStartDatesMessage =>
      'These timetables have no valid semester start date in the import. The dates below initially use today. Review them before importing.';

  @override
  String get importStartDateConfirmationRequiredMessage =>
      'Confirm the missing semester start dates before importing.';

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
      'Plan zajęć wybrany do zastąpienia jest niedostępny. Wybierz go ponownie.';

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
  String get weekdayShortMonday => 'pon.';

  @override
  String get weekdayShortTuesday => 'wt.';

  @override
  String get weekdayShortWednesday => 'śr.';

  @override
  String get weekdayShortThursday => 'czw.';

  @override
  String get weekdayShortFriday => 'pt.';

  @override
  String get weekdayShortSaturday => 'sob.';

  @override
  String get weekdayShortSunday => 'niedz.';

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
  String get firstLaunchPrivacyConsentBefore =>
      'Wybierając początkowy obszar roboczy, potwierdzasz, że znasz i akceptujesz ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Politykę prywatności';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Zmień tryb';

  @override
  String get switchToStudentTimetable => 'Przełącz na plan zajęć ucznia';

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
  String get reminder => 'Przypomnienie';

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
  String get generalFitWeekColumnsToWidth => 'Dopasuj widok tygodnia do ekranu';

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
  String get icsReminderExportTitle => 'Eksport ICS nie obejmuje przypomnień';

  @override
  String get icsReminderExportMessage =>
      'Przypomnienia nie są uwzględniane w wyeksportowanym pliku ICS. Wybierz JSON, aby zachować ustawienia przypomnień.';

  @override
  String get icsReminderExportJsonAction => 'Eksportuj JSON';

  @override
  String get icsReminderExportContinueAction => 'Kontynuuj z ICS';

  @override
  String get icsReminderImportNotice =>
      'Wydarzenia zaimportowane z ICS będą miały wyłączone przypomnienia. Użyj JSON, aby przywrócić ustawienia przypomnień.';

  @override
  String get icsReminderReplaceTitle => 'Zastąpić wydarzenia i przypomnienia?';

  @override
  String icsReminderReplaceMessage(String calendar) {
    return 'Zastąpienie kategorii „$calendar” wydarzeniami z ICS nadpisze jej wydarzenia i wyłączy ich przypomnienia. Anuluj, aby najpierw wyeksportować kopię zapasową JSON, lub wróć i dodaj nową kategorię.';
  }

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
    return 'Nieobsługiwane pola ICS zostały pominięte: $fields';
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
  String developerNotificationPlanError(Object message) {
    return 'Ostatni błąd: $message';
  }

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
  String get developerNotificationNextRenewal => 'Następna próba odnowienia';

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
  String get notificationSettingsSection => 'Przypomnienia i powiadomienia';

  @override
  String get notificationCoverage => 'Zakres przypomnień';

  @override
  String get notificationCoverageBlocked =>
      'Reminders are blocked and will not fire. Review the system requirements below.';

  @override
  String get notificationCoverageFailed =>
      'Reminders could not be synced. Open notification settings and try again.';

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
  String get notificationLockScreenTitles => 'Pokazuj tytuły w powiadomieniach';

  @override
  String get notificationLockScreenTitlesHint =>
      'Dotyczy także ekranu blokady. Po wyłączeniu powiadomienia zawierają tylko typ i godzinę.';

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
  String get settingsDataPrivacy => 'Dane i prywatność';

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
  String get colorPickerHue => 'Odcień';

  @override
  String get colorPickerSaturation => 'Nasycenie';

  @override
  String get colorPickerValue => 'Jasność';

  @override
  String get colorPickerHex => 'Kolor szesnastkowy';

  @override
  String get colorPickerSpectrum => 'Widmo kolorów';

  @override
  String get colorPickerSpectrumKeyboardHint =>
      'Użyj strzałek w lewo i w prawo, aby zmienić nasycenie, a w górę i w dół, aby zmienić jasność.';

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

  @override
  String get managePeriodTimeSets => 'Zarządzaj zestawami godzin lekcyjnych';

  @override
  String periodTimeSetUsageSummary(int periodCount, int timetableCount) {
    return 'Liczba lekcji: $periodCount · Powiązane plany: $timetableCount';
  }

  @override
  String chooseTimetableImportMethod(String name) {
    return 'Zaimportuj jako nowy plan zajęć lub zastąp wszystkie informacje i zajęcia w planie „$name”.';
  }

  @override
  String get selectAtLeastOneWeek => 'Wybierz co najmniej jeden tydzień.';

  @override
  String get notificationRemindHiddenGeneralCalendars =>
      'Zachowaj przypomnienia dla ukrytych kategorii';

  @override
  String get notificationRemindHiddenGeneralCalendarsHint =>
      'Dotyczy przypomnień w aplikacji i powiadomień systemowych. Powiadomienia systemowe muszą być również włączone w ustawieniach.';

  @override
  String get generalReminderFollowDefault => 'Użyj ustawień domyślnych';

  @override
  String get generalReminderCustom => 'Własne przypomnienia';

  @override
  String get eventEditScopeTitle => 'Edytuj wydarzenie cykliczne';

  @override
  String get eventEditThisOccurrence => 'Tylko to wystąpienie';

  @override
  String get eventEditThisAndFollowing => 'To i kolejne wystąpienia';

  @override
  String get eventEditEntireSeries => 'Cała seria';

  @override
  String get eventEditEntireSeriesHint =>
      'Zmiany obejmą całą serię, również minione wystąpienia.';

  @override
  String get eventEditConflict =>
      'To wydarzenie zostało zmienione. Wersja robocza została zachowana; otwórz wydarzenie ponownie, aby sprawdzić jego najnowszą wersję.';

  @override
  String eventSavedToHiddenCalendar(String name) {
    return 'Zapisano w ukrytej kategorii „$name”.';
  }

  @override
  String get viewEvent => 'Wyświetl wydarzenie';

  @override
  String get schoolSitesNameRequired => 'Wpisz nazwę szkoły.';

  @override
  String get schoolSitesLoginUrlRequired => 'Wpisz adres URL logowania.';

  @override
  String get languageNoResults => 'Brak pasujących języków';

  @override
  String get themeGeneralMonthTextColors => 'Tekst widoku miesiąca';

  @override
  String get themeGeneralFestivalTextColor => 'Święta i dni wolne';

  @override
  String get themeGeneralSolarTermTextColor => 'Okresy słoneczne';

  @override
  String get themeGeneralLunarTextColor => 'Daty księżycowe';

  @override
  String get courseTextLowContrastHint =>
      'Ten kolor tekstu może być trudny do odczytania na niektórych kartach kursów (kontrast poniżej 4.5:1). Możesz go zachować lub wybrać inny.';

  @override
  String get shortenSemesterTitle => 'Skrócić semestr?';

  @override
  String shortenSemesterMessage(int weeks, int count) {
    return 'Semestr zakończy się w tygodniu $weeks. Kursy z późniejszymi zajęciami: $count. Kursy i wybrane tygodnie zostaną zachowane. Przywróć liczbę tygodni, aby znów je zobaczyć.';
  }

  @override
  String get defaultGeneralCalendarName => 'Mój kalendarz';

  @override
  String get icsImportReportTitle => 'Raport importu';

  @override
  String get icsImportReportAction => 'Zobacz raport';

  @override
  String get icsExportFailureTitle => 'Nie można wyeksportować do ICS';

  @override
  String get icsCopyDiagnosticsAction => 'Kopiuj szczegóły';

  @override
  String get icsUnsupportedTimeZoneMessage =>
      'Ten ICS zawiera nazwane strefy czasowe, których Sked nie może bezpiecznie zinterpretować. Niczego nie zaimportowano. Wyeksportuj UTC lub lokalne czasy bez strefy czasowej z kalendarza źródłowego i spróbuj ponownie.';

  @override
  String get icsExportMonthlyAnchorMismatchMessage =>
      'Tego comiesięcznego wydarzenia nie można dokładnie przedstawić w ICS. Wyeksportuj JSON, aby zachować daty.';

  @override
  String get icsExportEmptyRecurrenceMessage =>
      'To wydarzenie cykliczne nie ma prawidłowych wystąpień do eksportu do ICS. Wyeksportuj JSON, aby zachować wpis.';

  @override
  String get icsImportedCalendarName => 'Zaimportowany kalendarz';

  @override
  String get icsUntitledEventName => 'Wydarzenie bez tytułu';

  @override
  String notificationWindowsCoverageLimit(int days, int capacity) {
    return 'Windows planuje przypomnienia tylko na najbliższe $days dni, maksymalnie $capacity naraz. Regularnie otwieraj aplikację ponownie, aby odświeżyć plan.';
  }

  @override
  String notificationWindowsCoverageSummary(int count, String date) {
    return 'Zaplanowane przypomnienia: $count. Ostatnie sprawdzenie obejmuje okres do $date.';
  }

  @override
  String get notificationWindowsCoverageCapacityLimited =>
      'Osiągnięto limit przypomnień. Niektóre nie są jeszcze zaplanowane. Po wyświetleniu najbliższych przypomnień otwórz aplikację ponownie, aby odświeżyć plan.';

  @override
  String get courseInactiveThisWeek => 'Brak zajęć w tym tygodniu';

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

  @override
  String get importWarningRecurrenceDateClamped =>
      'The repeat rule was kept. Dates missing from a month move to its last day; the source rule skips those dates. These moved dates count toward the repeat limit.';

  @override
  String importWarningSkippedRecurrenceOverride(Object fields) {
    return 'Skipped a recurrence override whose original occurrence could not be identified safely: $fields.';
  }

  @override
  String get importWarningSkippedCancelledEvent => 'Skipped a cancelled event.';

  @override
  String get importWarningSkippedEmptyRecurrence =>
      'Skipped a recurring event because UNTIL is before its first occurrence.';

  @override
  String importTextFileTooLarge(Object size) {
    return 'Text files must be $size MB or smaller.';
  }

  @override
  String icsImportReviewNotice(Object count, Object warningCount) {
    return 'Ready to import $count events with $warningCount warnings. Review all skipped events and changes below. Nothing has been saved yet.';
  }

  @override
  String get icsImportContinueAction => 'Continue import';

  @override
  String importWarningRecurrenceRuleDowngraded(Object fields) {
    return 'This event will be imported as a single event. Unsupported fields or rule parts: $fields.';
  }

  @override
  String get notificationSnoozeAction => 'Odłóż o 10 minut';

  @override
  String get notificationHandledAction => 'Oznacz jako obsłużone';

  @override
  String get developerTestNotificationTitle => 'Powiadomienie testowe Sked';

  @override
  String get developerTestNotificationCourseBody =>
      'Kanał przypomnień o kursach działa.';

  @override
  String get developerTestNotificationScheduleBody =>
      'Kanał przypomnień o wydarzeniach działa.';

  @override
  String get eventRecurrenceExceptionsChangeTitle => 'Change repeat pattern?';

  @override
  String get eventRecurrenceExceptionsChangeMessage =>
      'Previously skipped dates stay skipped only if the new repeat pattern still has an occurrence on that date. Other skip records will be removed. Turning repeats off removes all skip records. Events edited separately stay unchanged.';
}
