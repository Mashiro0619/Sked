// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Week $week';
  }

  @override
  String get addCourse => 'Vak toevoegen';

  @override
  String get settings => 'Instellingen';

  @override
  String get multiTimetableSwitch => 'Wisselen van rooster';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Huidig rooster · $weeks weken';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Tik om te wisselen · $weeks weken';
  }

  @override
  String get editTimetable => 'Rooster bewerken';

  @override
  String get schoolImportResultEditorTitle => 'Analyseresultaat bewerken';

  @override
  String get schoolImportParsePageTitle => 'Rooster analyseren';

  @override
  String get schoolImportParsePageParsing => 'Analyseren…';

  @override
  String get schoolImportParsePageFailed => 'Analyse mislukt';

  @override
  String get schoolImportParsePageComplete => 'Analyse voltooid';

  @override
  String get schoolImportParsePageContinue => 'Doorgaan';

  @override
  String get schoolImportParsePageRawContent => 'Onbewerkt antwoord';

  @override
  String get schoolImportParsePageExpandRaw => 'Onbewerkt antwoord uitvouwen';

  @override
  String get schoolImportParsePageCollapseRaw =>
      'Onbewerkt antwoord samenvouwen';

  @override
  String get schoolImportExpandWarnings => 'Importmeldingen uitvouwen';

  @override
  String get schoolImportCollapseWarnings => 'Importmeldingen samenvouwen';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Sommige vakken lopen door tot week $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle => 'Huidig rooster vervangen?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Het geïmporteerde rooster vervangt het huidige rooster.';

  @override
  String get createTimetable => 'Nieuw rooster';

  @override
  String get jumpToWeek => 'Ga naar week';

  @override
  String get timetable => 'Rooster';

  @override
  String get themeWorkspaceSchedule => 'Agenda';

  @override
  String get timetableName => 'Naam van het rooster';

  @override
  String get timetableNameRequired => 'Voer een naam voor het rooster in';

  @override
  String get totalWeeks => 'Totaal aantal weken';

  @override
  String get delete => 'Verwijderen';

  @override
  String get cancel => 'Annuleren';

  @override
  String get save => 'Opslaan';

  @override
  String get deleteTimetableTitle => 'Rooster verwijderen';

  @override
  String deleteTimetableMessage(Object name) {
    return '‘$name’ verwijderen?';
  }

  @override
  String get noTimetableTitle => 'Nog geen rooster';

  @override
  String get noTimetableMessage =>
      'Maak een rooster of importeer er een uit een JSON-bestand.';

  @override
  String get importTimetable => 'Rooster importeren';

  @override
  String get courseName => 'Naam van het vak';

  @override
  String get location => 'Locatie';

  @override
  String get dayOfWeek => 'Dag';

  @override
  String get semesterWeeks => 'Weken';

  @override
  String get startTime => 'Begintijd';

  @override
  String get endTime => 'Eindtijd';

  @override
  String get linkedPeriods => 'Gekoppelde lesuren';

  @override
  String get linkedPeriodsUnmatched =>
      'Geen lesuren gevonden voor de huidige tijd. Tik om ze handmatig te kiezen.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Lesuur $start-$end';
  }

  @override
  String get teacherName => 'Docent';

  @override
  String get credits => 'Studiepunten';

  @override
  String get remarks => 'Opmerkingen';

  @override
  String get customFields => 'Eigen velden';

  @override
  String get customFieldsHint => 'Eén per regel, als sleutel:waarde';

  @override
  String get more => 'Meer';

  @override
  String get selectDayOfWeek => 'Kies een dag';

  @override
  String get selectSemesterWeeks => 'Kies weken';

  @override
  String get selectAll => 'Alles selecteren';

  @override
  String get clear => 'Wissen';

  @override
  String get confirm => 'Bevestigen';

  @override
  String get selectLinkedPeriods => 'Kies gekoppelde lesuren';

  @override
  String get addCourseTitle => 'Vak toevoegen';

  @override
  String get editCourseTitle => 'Vak bewerken';

  @override
  String get editCourseTooltip => 'Vak bewerken';

  @override
  String get place => 'Locatie';

  @override
  String get time => 'Tijd';

  @override
  String get notFilled => 'Niet ingevuld';

  @override
  String get none => 'Geen';

  @override
  String get conflictCourses => 'Overlappende vakken';

  @override
  String get locationNotFilled => 'Locatie niet ingevuld';

  @override
  String get setAsDisplayed => 'Dit vak weergeven';

  @override
  String get editThisCourse => 'Dit vak bewerken';

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get settingsSectionTimetable => 'Rooster';

  @override
  String get settingsSectionGeneralSchedule => 'Agenda';

  @override
  String get settingsSectionAppearance => 'Weergave';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionWorkspace => 'Werkruimte';

  @override
  String get settingsSectionAppearanceLanguage => 'Weergave en taal';

  @override
  String get settingsSectionDataSecurity => 'Gegevens en beveiliging';

  @override
  String get settingsSectionAbout => 'Over Sked';

  @override
  String get noTimetableSettings =>
      'Er is momenteel geen rooster om in te stellen.';

  @override
  String get semesterStartDate => 'Begindatum van het semester';

  @override
  String get periodTimeSets => 'Lestijdenschema';

  @override
  String get noPeriodTimeAvailable => 'Geen lestijdenschema beschikbaar';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count lesuren';
  }

  @override
  String get coursePopupDismissSetting =>
      'Vakvenster sluiten door erbuiten te tikken';

  @override
  String get coursePopupDismissSettingHint =>
      'Als dit uitstaat, kan het venster ook niet door omlaag vegen worden gesloten.';

  @override
  String get preserveTimetableGaps => 'Tussenruimtes in het rooster behouden';

  @override
  String get preserveTimetableGapsHint =>
      'Als dit uitstaat, worden lunchpauzes en andere tussenruimtes samengevouwen, zodat latere lessen omhoogschuiven.';

  @override
  String get showPastEndedCourses => 'Afgelopen vakken weergeven';

  @override
  String get showPastEndedCoursesHint =>
      'Toon vakken die vóór de werkelijk huidige week zijn afgelopen in een lichtere grijze stijl.';

  @override
  String get showFutureCourses => 'Toekomstige vakken weergeven';

  @override
  String get showFutureCoursesHint =>
      'Toon vakken die deze week niet plaatsvinden maar in latere weken wel, in een grijze stijl.';

  @override
  String get timetableDisplaySettings => 'Roosterweergave en bediening';

  @override
  String get timetableDisplaySettingsDesc =>
      'Vakweergave, indeling, weekgebaren en snel toevoegen';

  @override
  String get showTimetableGridLines => 'Rasterlijnen in het rooster tonen';

  @override
  String get showTimetableGridLinesHint =>
      'Bepaalt of horizontale en verticale rasterlijnen zichtbaar zijn in het rooster.';

  @override
  String get timetableHorizontalLayoutSection =>
      'Horizontale indeling en gebaren';

  @override
  String get fitDaySelectorToWidth => 'Dagkeuze aanpassen aan het scherm';

  @override
  String get fitDaySelectorToWidthHint =>
      'Toon indien mogelijk alle zeven dagen op het scherm. Zet dit uit om een vaste breedte te gebruiken en te scrollen.';

  @override
  String get fitWeekColumnsToWidth => 'Weekkolommen aanpassen aan het scherm';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Toon indien mogelijk alle zeven roosterkolommen op het scherm. Zet dit uit om een vaste breedte te gebruiken en te scrollen.';

  @override
  String get enableWeekSwipeNavigation => 'Vegen om van week te wisselen';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Veeg naar links of rechts om naar een andere week te gaan. Sleep bij vaste breedtes eerst voorbij de rand.';

  @override
  String get liveCourseOutlineColor => 'Randkleur van vakken';

  @override
  String get liveCourseOutlineColorHint =>
      'Kies of de rand het huidige of volgende vak markeert, of alle weergegeven vakken op de huidige pagina.';

  @override
  String get liveCourseOutlineSettings => 'Rand rond vakken';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Stel in of de rand wordt getoond, welke vakken hij markeert, of hij de themakleur volgt en welke kleur wordt gebruikt.';

  @override
  String get liveCourseOutlineEnabled => 'Rand inschakelen';

  @override
  String get liveCourseOutlineFollowTheme => 'Themakleur volgen';

  @override
  String get liveCourseOutlineTarget => 'Vakken met een rand';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Huidig of volgend vak';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Alle weergegeven vakken';

  @override
  String get liveCourseOutlineEffectiveColor => 'Gebruikte kleur';

  @override
  String get liveCourseOutlineCustomColor => 'Eigen randkleur';

  @override
  String get liveCourseOutlineWidth => 'Randbreedte';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Taal';

  @override
  String get languagePageDescription =>
      'Kies een van de talen die in de app beschikbaar zijn.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API-antwoord';

  @override
  String get theme => 'Thema';

  @override
  String get themeFollowSystem => 'Systeem volgen';

  @override
  String get themeLight => 'Licht';

  @override
  String get themeDark => 'Donker';

  @override
  String get themeColor => 'Themakleur';

  @override
  String get themeColorModeSingle => 'Eén themakleur';

  @override
  String get themeColorModeColorful => 'Meerdere kleuren';

  @override
  String get themeColorUiColors => 'Interfacekleuren';

  @override
  String get themeColorCourseColors => 'Vakkleuren';

  @override
  String get themeColorPrimary => 'Primair';

  @override
  String get themeColorSecondary => 'Secundair';

  @override
  String get themeColorTertiary => 'Tertiair';

  @override
  String get themeColorCourseText => 'Vaktekst';

  @override
  String get themeColorCourseTextAuto => 'Auto';

  @override
  String get themeColorCourseTextCustom => 'Eigen kleur';

  @override
  String get themeColorCourseColorsEmpty =>
      'Vakkleuren worden aangemaakt nadat een rooster is geïmporteerd.';

  @override
  String get themeCustomColor => 'Eigen kleur';

  @override
  String get themeApplyCustomColor => 'Kleur toepassen';

  @override
  String get themeApplySettings => 'Instellingen toepassen';

  @override
  String get dataImportExport => 'Gegevens importeren en exporteren';

  @override
  String get dataImportExportDesc =>
      'Importeer alle gegevens of afzonderlijke roosters, of exporteer het huidige rooster of alle roosters.';

  @override
  String get appBackupTitle => 'App-back-up en herstel';

  @override
  String get appBackupSubtitle =>
      'Maak een back-up van roosters, agenda\'s, instellingen en schoolsites of herstel ze. API-sleutels worden niet meegenomen.';

  @override
  String get appBackupSheetSubtitle =>
      'Een volledig herstel vervangt de huidige appgegevens. AI-API-sleutels staan in beveiligde opslag en worden niet naar back-upbestanden geschreven.';

  @override
  String get restoreBackupFileTitle => 'Herstellen vanuit JSON-bestand';

  @override
  String get restoreBackupFileSubtitle =>
      'Kies een volledig Sked-back-upbestand. Je bevestigt voordat er wordt hersteld.';

  @override
  String get restoreBackupTextTitle => 'Back-up-JSON plakken';

  @override
  String get restoreBackupTextSubtitle =>
      'Plak een volledige back-up en herstel de huidige appgegevens.';

  @override
  String get shareBackupTitle => 'Back-upbestand delen';

  @override
  String get shareBackupSubtitle =>
      'Exporteer alle appgegevens als JSON. API-sleutels worden uitgesloten.';

  @override
  String get saveBackupTitle => 'Back-upbestand opslaan';

  @override
  String get saveBackupSubtitle =>
      'Sla een volledige app-back-up op in een lokaal bestand.';

  @override
  String get copyBackupTitle => 'Back-uptekst kopiëren';

  @override
  String get copyBackupSubtitle =>
      'Toon de volledige back-up-JSON zodat je deze kunt kopiëren of tijdelijk bewaren.';

  @override
  String get restoreBackupConfirmTitle => 'Volledige back-up herstellen?';

  @override
  String get restoreBackupConfirmMessage =>
      'Dit vervangt alle huidige roosters, algemene agenda\'s, instellingen en schoolsites. API-sleutels worden niet uit back-ups geïmporteerd; voer de sleutel opnieuw in voordat je opnieuw roosters parseert.';

  @override
  String get restoreBackupConfirmAction => 'Back-up herstellen';

  @override
  String get restoreBackupSuccessMessage =>
      'Volledige app-back-up hersteld. AI-API-sleutels moeten opnieuw worden ingevoerd.';

  @override
  String get restoreBackupFailureMessage =>
      'Herstellen mislukt. Controleer de inhoud van de back-up en probeer het opnieuw.';

  @override
  String get openSourceLicenses => 'Opensourcelicenties';

  @override
  String get openSourceLicensesDesc =>
      'Bekijk de licenties van Flutter-afhankelijkheden en meegeleverde app-pictogrammen.';

  @override
  String get checkForUpdates => 'Controleren op updates';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String get microsoftStoreUpdates =>
      'Updates worden beheerd door de Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Voorlopige updates ontvangen';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Neem Alpha-, Beta- en RC-versies op, die instabiel kunnen zijn. Uitgeschakeld worden alleen stabiele versies aangeboden.';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Je gebruikt al de nieuwste versie ($version)';
  }

  @override
  String get currentVersionLabel => 'Huidige versie';

  @override
  String get newVersionAvailable => 'Update beschikbaar';

  @override
  String get latestVersionLabel => 'Nieuwste versie';

  @override
  String get updateContentLabel => 'Updatedetails';

  @override
  String get officialWebsite => 'Officiële website';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Cloudopslag';

  @override
  String get ignoreThisVersion => 'Deze versie negeren';

  @override
  String get openUpdatesFailed => 'De updatelink kan niet worden geopend';

  @override
  String get updateCheckFailedTitle => 'Controleren op updates mislukt';

  @override
  String get updateCheckFailedMessage =>
      'De nieuwste versie kan niet van GitHub worden opgehaald. Je kunt hieronder wel de GitHub-releases openen.';

  @override
  String get githubRepository => 'GitHub-repository';

  @override
  String get googlePlayStoreDesc => 'Sked bekijken op Google Play';

  @override
  String get openGooglePlayFailed => 'Google Play kan niet worden geopend';

  @override
  String get starSkedOnGithub => 'Geef Sked een ster op GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Open de projectrepository en geef Sked een ster';

  @override
  String get openGithubFailed =>
      'De GitHub-repositorylink kan niet worden geopend';

  @override
  String get openPrivacyPolicyFailed =>
      'Kan de link naar het privacybeleid niet openen';

  @override
  String get selectPeriodTimeSet => 'Kies een lestijdenschema';

  @override
  String get newItem => 'Nieuw';

  @override
  String get editPeriodTimeSet => 'Lestijdenschema bewerken';

  @override
  String get importTimetableFiles => 'Rooster importeren';

  @override
  String get importTimetableFilesDesc =>
      'Ondersteunt één of meerdere roosterbestanden.';

  @override
  String get importTimetableText => 'Import timetable from text';

  @override
  String get importTimetableTextDesc =>
      'Plak de JSON-inhoud van het rooster en importeer deze.';

  @override
  String get shareTimetableFiles => 'Roosterbestanden delen';

  @override
  String get shareTimetableFilesDesc => 'Kies eerst één of meer roosters.';

  @override
  String get saveTimetableFiles => 'Roosterbestanden opslaan';

  @override
  String get saveTimetableFilesDesc => 'Kies eerst één of meer roosters.';

  @override
  String get exportTimetableText => 'Export timetable as text';

  @override
  String get exportTimetableTextDesc =>
      'Kies één of meer roosters en kopieer vervolgens de JSON-inhoud.';

  @override
  String get jsonContent => 'JSON-inhoud';

  @override
  String get pasteJsonContentHint =>
      'Plak de JSON-inhoud die je wilt importeren.';

  @override
  String get jsonContentEmpty => 'Plak eerst JSON-inhoud.';

  @override
  String get copyText => 'Kopiëren';

  @override
  String get copiedToClipboard => 'Gekopieerd naar het klembord';

  @override
  String get share => 'Delen';

  @override
  String get selectTimetablesToExport => 'Kies roosters om te exporteren';

  @override
  String get selectTimetablesToImport => 'Kies roosters om te importeren';

  @override
  String timetableCourseCount(int count) {
    return '$count vakken';
  }

  @override
  String get importAction => 'Importeren';

  @override
  String get importTimetableDialogTitle => 'Rooster importeren';

  @override
  String get chooseImportMethod => 'Kies hoe je wilt importeren.';

  @override
  String get importAsNewTimetable => 'Importeren als nieuw rooster';

  @override
  String get replaceCurrentTimetable => 'Huidig rooster vervangen';

  @override
  String get importPeriodTimeSetDialogTitle => 'Lestijdenschema’s importeren';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Dit bestand bevat meegeleverde lestijdenschema’s. Wil je deze importeren en koppelen?';

  @override
  String get importBundledPeriodTimeSets => 'Importeren en koppelen';

  @override
  String get discardBundledPeriodTimeSets => 'Meegeleverde schema’s overslaan';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Er is geen bestaand lestijdenschema beschikbaar. Daarom kunnen de meegeleverde schema’s niet worden overgeslagen.';

  @override
  String savedToPath(Object path) {
    return 'Opgeslagen in $path';
  }

  @override
  String get saveCancelled => 'Opslaan geannuleerd';

  @override
  String get fileSaveRestrictedTitle => 'Bestanden opslaan is beperkt';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Het systeem kon het bestand niet opslaan. Probeer het opnieuw of gebruik delen.';

  @override
  String get retrySave => 'Opnieuw opslaan';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Geef in de systeeminstellingen toegang tot bestanden en probeer daarna opnieuw te exporteren.';

  @override
  String get openSettings => 'Instellingen openen';

  @override
  String get browserDownloadRestrictedTitle =>
      'Downloaden in de browser is beperkt';

  @override
  String get browserDownloadRestrictedMessage =>
      'Deze browser ondersteunt rechtstreeks opslaan in een lokaal bestand niet. Controleer de downloadmachtigingen van de browser of gebruik bestanden delen.';

  @override
  String get switchToShare => 'In plaats daarvan delen';

  @override
  String get fileSaveFailedTitle => 'Bestand opslaan mislukt';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Er kan niet naar het huidige pad worden geschreven. De doelmap is mogelijk beveiligd, het bestand is in gebruik of het pad is niet beschrijfbaar.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Het systeem kon het bestand niet opslaan. Probeer het opnieuw, controleer de systeeminstellingen of gebruik bestanden delen.';

  @override
  String get retryLater => 'Later opnieuw proberen';

  @override
  String get exportSwitchedToShare =>
      'Voor het exporteren overgeschakeld naar bestanden delen';

  @override
  String get saveFailedRetry => 'Opslaan mislukt. Probeer het later opnieuw.';

  @override
  String get periodTimesUnsavedExitTitle => 'Wijzigingen niet opgeslagen';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'De laatste wijzigingen aan de lestijden konden niet worden opgeslagen. Je kunt het opnieuw proberen, verder bewerken of de wijzigingen verwerpen.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Sommige lestijden zijn ongeldig. Corrigeer ze voordat je opslaat, of verwerp de wijzigingen en verlaat de pagina.';

  @override
  String get discardChangesAndExit => 'Verwerpen en sluiten';

  @override
  String get appInstanceBlockedTitle => 'Sked is al geopend';

  @override
  String get appInstanceBlockedMessage =>
      'Een ander Sked-venster of een ander browsertabblad gebruikt je lokale gegevens. Sluit het andere venster of tabblad en probeer het opnieuw.';

  @override
  String get appInstanceLeaseFailedTitle =>
      'Lokale gegevens zijn niet beschikbaar';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked kon de exclusieve toegang tot lokale gegevens niet controleren. Je gegevens zijn niet geopend of gewijzigd. Controleer de toegang tot de opslag en probeer het opnieuw.';

  @override
  String get savingChanges => 'Wijzigingen worden opgeslagen...';

  @override
  String get showApiKey => 'API-sleutel tonen';

  @override
  String get hideApiKey => 'API-sleutel verbergen';

  @override
  String get importFailedCheckContent =>
      'Importeren mislukt. Controleer de inhoud van het bestand.';

  @override
  String get noImportableTimetables =>
      'Er zijn geen bruikbare roosters gevonden in het geïmporteerde bestand.';

  @override
  String importedTimetablesCount(int count) {
    return '$count roosters geïmporteerd';
  }

  @override
  String get periodTimesTitle => 'Lestijden';

  @override
  String get importExport => 'Importeren en exporteren';

  @override
  String get importPeriodTemplate => 'Lestijdensjabloon importeren';

  @override
  String get importPeriodTemplateText =>
      'Lestijdensjabloon uit tekst importeren';

  @override
  String get sharePeriodTemplate => 'Lestijdensjabloon delen';

  @override
  String get saveTemplateToFile => 'Sjabloon opslaan in een bestand';

  @override
  String get exportPeriodTemplateText =>
      'Lestijdensjabloon als tekst exporteren';

  @override
  String get deletePeriodTimeSet => 'Lestijdenschema verwijderen';

  @override
  String get periodTimeSetName => 'Naam van het lestijdenschema';

  @override
  String get addOnePeriod => 'Lesuur toevoegen';

  @override
  String periodNumberLabel(int index) {
    return 'Lesuur $index';
  }

  @override
  String get deleteThisPeriod => 'Dit lesuur verwijderen';

  @override
  String durationMinutes(int minutes) {
    return 'Duur: $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Pauze na het vorige lesuur: $minutes min';
  }

  @override
  String get endTimeMustBeLater => 'De eindtijd moet na de begintijd liggen';

  @override
  String get periodOverlapPrevious => 'Dit lesuur overlapt het vorige';

  @override
  String get periodTimesSaved => 'Lestijden opgeslagen';

  @override
  String get deletePeriodTimeSetTitle => 'Lestijdenschema verwijderen';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return '‘$name’ verwijderen?';
  }

  @override
  String get currentPeriodTimeSet => 'huidig lestijdenschema';

  @override
  String importedPeriodTimesCount(int count) {
    return '$count lestijden geïmporteerd';
  }

  @override
  String get periodFilePermissionTitle => 'Bestandsmachtiging nodig';

  @override
  String get androidFilePermissionMessage =>
      'Exporteren op Android vereist toegang tot bestanden. Geef toestemming om verder op te slaan.';

  @override
  String get reauthorize => 'Opnieuw toestemming geven';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Toestemming definitief geweigerd';

  @override
  String get permissionSettingsExportMessage =>
      'Geef in de systeeminstellingen toegang tot bestanden en probeer daarna opnieuw te exporteren.';

  @override
  String get privacyPolicyTitle => 'Privacybeleid';

  @override
  String get privacyPolicyEntryDesc =>
      'Learn how the app handles local storage, school-site configuration, file import/export, webpage parsing, and external links.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Geaccepteerde versie: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked is een lokaal-eerst roosterhulpmiddel. Roosters, periodetijdsets en schoolwebsiteconfiguratie worden alleen op je apparaat of in je browser opgeslagen en worden nooit automatisch geüpload. De app verwerkt alleen gegevens wanneer je expliciet acties start zoals importeren, webpagina-analyse, delen of het openen van externe links. Het volledige privacybeleid is online beschikbaar.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Lokale opslag';

  @override
  String get privacyPolicyLocalStorageBody =>
      'Op native platforms bewaart Sked roosters, agenda’s, bijbehorende instellingen en bewerkbare schoolwebsiteconfiguraties in de map voor toepassingsgegevens van het besturingssysteem. De webversie gebruikt de opslag van de browser. Bestanden die oudere versies in de map Documenten van de gebruiker hebben geplaatst, blijven daar staan, maar worden niet automatisch gelezen of gemigreerd. Exporteer vóór de upgrade een volledige app-back-up vanuit de oude versie en zet deze daarna terug om die gegevens te behouden. De instellingen voor de AI-API worden lokaal opgeslagen. De eigen API-sleutel wordt waar mogelijk in de beveiligde opslag van het platform bewaard. Volledige app-back-ups bevatten de eigen API-sleutel niet. De app uploadt deze lokale gegevens niet automatisch naar een server die door de ontwikkelaar wordt beheerd.';

  @override
  String get privacyPolicyImportExportTitle => 'Importeren en exporteren';

  @override
  String get privacyPolicyImportExportBody =>
      'The app reads or writes timetable JSON files, school-site JSON files, and period-template files only when you explicitly choose a file or start an export action. Importing these files is a local operation unless you also choose webpage parsing. Fetching a custom model list is also an explicit network action and only contacts the custom endpoint you configured.';

  @override
  String get privacyPolicySharingTitle => 'Delen';

  @override
  String get privacyPolicySharingBody =>
      'Als je zelf kiest om te delen, geeft de app het geëxporteerde bestand door aan het deelvenster van het systeem of aan de app die je kiest. Hoe het bestand daarna wordt verwerkt, hangt af van de gekozen app of dienst.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Externe links';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Als je externe links opent, zoals de GitHub-repository, geeft de app de actie door aan je browser of een andere externe toepassing. De verdere verwerking van gegevens valt onder het beleid van de derde partij die je opent.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Wat de app niet verzamelt';

  @override
  String get privacyPolicyNoCollectionBody =>
      'De app vereist geen Sked-account en schakelt geen analyses, advertentie-identificatoren of cloudback-ups in. De app heeft ook geen apart veld om wachtwoorden van schoolaccounts te verzamelen. Als je in de app inlogt op een schoolwebsite, gebeurt die interactie op de schoolpagina die je hebt geopend.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Webpage parsing';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Wanneer je schoolwebpagina-import gebruikt of geplakte roostertekst / HTML analyseert, bereidt en schoont de app de inhoud eerst lokaal op en verzendt daarna de ingediende roostertekst, paginatekst of HTML-inhoud, de optionele paginatitel en URL, de huidige app-taal en de parserprompt naar het OpenAI-compatibele endpoint dat je hebt geconfigureerd. Het ophalen van de modellenlijst vraagt ook datzelfde endpoint aan. Sked biedt geen ingebouwd parser-endpoint en verzendt geen parseraanvragen naar een door de ontwikkelaar beheerde roosterparser-backend. Het aangepaste endpoint en eventuele upstreamdiensten kunnen gegevens opslaan, doorsturen, beperken, verwijderen of anderszins verwerken volgens de regels van de door jou gekozen serviceprovider. Als je een http:// Base URL gebruikt, gebruik die dan alleen op vertrouwde apparaten, vertrouwde netwerken en vertrouwde endpointdiensten, omdat inhoud en API-sleutels mogelijk niet door transportversleuteling worden beschermd.';

  @override
  String get privacyPolicyUpdatesTitle => 'Wijzigingen in het beleid';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'De huidige versie van het privacybeleid is $version. Als een latere versie verandert hoe gegevens worden verwerkt, kan de app je vragen het aangepaste beleid opnieuw te lezen en te accepteren.';
  }

  @override
  String get privacyGateTitle =>
      'Ga akkoord met het privacybeleid voordat je de app gebruikt';

  @override
  String get privacyGateSummaryStorage =>
      'Timetables, period-time sets, and school-site configuration are only stored locally and are not automatically uploaded to a developer server.';

  @override
  String get privacyGateSummaryImportExport =>
      'Import, export, and sharing only happen when you explicitly start them; webpage parsing sends only the submitted content to your configured parsing endpoint, and you can review the parsed timetable before saving.';

  @override
  String get privacyGateSummaryUpdates =>
      'Als een latere versie de verwerking van gegevens verandert, kan de app je vragen het aangepaste privacybeleid opnieuw te bekijken.';

  @override
  String get schoolWebImportEntry => 'Importeren van een schoolwebsite';

  @override
  String get schoolWebImportEntryDesc =>
      'Importeer de huidige roosterpagina van de schoolwebsite.';

  @override
  String get schoolSitesManageEntry => 'Schoolwebsites beheren';

  @override
  String get schoolSitesManageEntryDesc =>
      'Voeg inlog-URL’s van scholen toe, bewerk of verwijder ze, met JSON-import en -export.';

  @override
  String get schoolSitesPageTitle => 'Schoolwebsites beheren';

  @override
  String get schoolSitesImportJson => 'JSON met schoolwebsites importeren';

  @override
  String get schoolSitesShareJson => 'JSON met schoolwebsites delen';

  @override
  String get schoolSitesSaveJson => 'JSON met schoolwebsites opslaan';

  @override
  String get schoolSitesSaved => 'Schoolwebsites opgeslagen';

  @override
  String get schoolSitesImported => 'Schoolwebsites geïmporteerd';

  @override
  String get schoolSitesImportPreviewTitle =>
      'Import van schoolwebsites controleren';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount geldige websites, $invalidCount ongeldige vermeldingen.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Het bestand bevat een lege lijst met schoolwebsites.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Vermelding $position is ongeldig en wordt overgeslagen.';
  }

  @override
  String get schoolSitesImportMerge => 'Samenvoegen';

  @override
  String get schoolSitesImportReplace => 'Vervangen';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Huidige schoolwebsites vervangen?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Hiermee worden $currentCount huidige websites verwijderd en $importedCount geïmporteerde websites opgeslagen. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Schoolwebsitegegevens moeten worden hersteld';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked kon het schoolwebsitebestand en de back-up ervan niet lezen. Voordat schrijven werd geblokkeerd, zijn beschermde kopieën gemaakt.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Opslag voor schoolwebsites niet beschikbaar';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked heeft momenteel geen toegang tot de opslag voor schoolwebsites. Controleer de opslagtoegang en de beschikbaarheid van het apparaat en probeer het opnieuw. De huidige websitegegevens worden niet overschreven.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Herstelbestanden en betrokken opslaglocaties staan hieronder. Wijzig geen bestanden totdat de lijst met websites is hersteld.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Opnieuw beginnen zonder schoolwebsites';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Beginnen met een lege lijst met schoolwebsites?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'De beschermde kopieën blijven bewaard, maar Sked maakt een nieuw, leeg schoolwebsitebestand. Ga alleen verder als je het herstel niet eerst opnieuw wilt proberen.';

  @override
  String get schoolSitesEmpty => 'Nog geen schoolwebsites ingesteld.';

  @override
  String get schoolSitesNameLabel => 'Naam van de school';

  @override
  String get schoolSitesLoginUrlLabel => 'Inlog-URL';

  @override
  String get schoolSitesAdd => 'School toevoegen';

  @override
  String get schoolSitesEdit => 'School bewerken';

  @override
  String get schoolSitesDeleteTitle => 'School verwijderen';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return '‘$name’ verwijderen?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Vul eerst de schoolnaam en inlog-URL in.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Import by pasting timetable page content';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Paste source code or raw page content containing timetable information manually.';

  @override
  String get schoolHtmlImportPageTitle => 'Parse timetable from page content';

  @override
  String get schoolHtmlImportUrlLabel => 'Bron-URL (optioneel)';

  @override
  String get schoolHtmlImportTitleLabel => 'Paginatitel (optioneel)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Page content';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Paste source code or raw page content containing timetable information here.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Any content containing timetable information can be parsed and imported, not just HTML.';

  @override
  String get schoolHtmlImportCompress => 'Inhoud voorbereiden';

  @override
  String get schoolHtmlImportCompressed => 'Inhoud voorbereid';

  @override
  String get schoolHtmlImportCompressFirst => 'Bereid eerst de inhoud voor.';

  @override
  String get schoolHtmlImportSubmit => 'Analyseren en importeren';

  @override
  String get schoolImportContentTruncated =>
      'Deze pagina heeft de veilige importlimiet bereikt. Alleen het vastgelegde gedeelte wordt verzonden voor analyse.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Het analyseren kan even duren. Even geduld.';

  @override
  String get schoolHtmlImportEmpty => 'Paste the page HTML first.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Terug naar de webpagina';

  @override
  String get schoolWebImportPageTitle => 'Importeren van een schoolwebsite';

  @override
  String get schoolWebImportPreview => 'Importvoorbeeld';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count vakken';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count lesuren';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Paginatitel';

  @override
  String get schoolWebImportParserUsed => 'Parser';

  @override
  String get schoolWebImportWarnings => 'Importopmerkingen';

  @override
  String get schoolWebImportParserDetails => 'Analysedetails';

  @override
  String get schoolWebImportExpandParserDetails => 'Analysedetails uitvouwen';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Analysedetails samenvouwen';

  @override
  String get schoolWebImportOpenPageHint =>
      'Log in de app in op de schoolwebsite en ga vervolgens zelf naar de roosterpagina.';

  @override
  String get schoolWebImportConfigMissing =>
      'De instellingen van de eigen parser zijn onvolledig. Vul eerst de basis-URL, API-sleutel en het model in.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Dit platform ondersteunt ingebouwd inloggen op websites nog niet. Gebruik een platform met WebView-ondersteuning.';

  @override
  String get schoolWebImportSelectSchool => 'Kies een school';

  @override
  String get schoolWebImportNoSchools =>
      'Er zijn geen scholen ingesteld. Controleer eerst school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Schoolinstellingen laden mislukt. Controleer de indeling van het JSON-bestand.';

  @override
  String get schoolWebImportImportCurrentPage => 'Huidige pagina importeren';

  @override
  String get schoolWebImportLoadingPage => 'Pagina laden…';

  @override
  String get schoolWebImportParsing => 'Huidige pagina analyseren…';

  @override
  String get schoolWebImportLoadFailed =>
      'Pagina laden mislukt. Vernieuw de pagina of probeer het later opnieuw.';

  @override
  String get schoolWebImportUnknownOrigin => 'Onbekende website';

  @override
  String get schoolWebImportExitTitle => 'Browser verlaten?';

  @override
  String get schoolWebImportExitMessage =>
      'De pagina wordt gesloten. Alles wat u nog niet hebt geïmporteerd, gaat verloren.';

  @override
  String get schoolWebImportExitConfirm => 'Verlaten';

  @override
  String get schoolWebImportEmptyPage =>
      'De huidige pagina is leeg en kan nog niet worden geïmporteerd.';

  @override
  String get schoolWebImportSuccess => 'Webrooster geïmporteerd';

  @override
  String get schoolImportParserSettingsTitle => 'API voor roosterimport';

  @override
  String get schoolImportParserSettingsDesc =>
      'Stel de OpenAI-compatibele API in voor het importeren van roosters, niet voor een chatassistent.';

  @override
  String get schoolImportParserSourceTitle => 'Parserbron';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Eigen OpenAI-compatibele dienst';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Eigen OpenAI-compatibele parser';

  @override
  String get schoolImportParserCustomPromptTitle => 'Eigen prompt';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Bewerk hier de ingebouwde parserprompt. Wijzigingen gelden alleen voor de eigen OpenAI-compatibele parser.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Standaard staat hier de ingebouwde prompt. Wis dit veld om de ingebouwde versie te gebruiken.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Standaardprompt herstellen';

  @override
  String get schoolImportParserBaseUrl => 'Basis-URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'De Base URL moet een HTTP- of HTTPS-URL met host zijn.';

  @override
  String get schoolImportParserApiKey => 'API-sleutel';

  @override
  String get schoolImportParserModel => 'Model';

  @override
  String get schoolImportParserFetchModels => 'Modellenlijst ophalen';

  @override
  String get schoolImportParserFetchingModels => 'Modellen ophalen…';

  @override
  String get schoolImportParserNoModelsFound =>
      'Het eindpunt heeft geen modellen teruggegeven.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Kan modellen niet ophalen. Controleer het eindpunt en probeer het opnieuw.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return '$count modellen opgehaald';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'De eigen API-sleutel wordt waar mogelijk in de beveiligde opslag van het platform bewaard. Gebruik eigen parsergegevens en HTTP-eindpunten alleen op apparaten, in browsers en op netwerken die je vertrouwt.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Een niet-versleuteld HTTP-eindpunt gebruiken?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'De API-sleutel en de inhoud van het rooster kunnen tijdens de overdracht worden gelezen of gewijzigd. Ga alleen door als u dit apparaat, netwerk en eindpunt vertrouwt. Deze toestemming blijft geldig totdat u Sked sluit.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'De instellingen van de eigen parser zijn onvolledig. Vul eerst de basis-URL, API-sleutel en het model in.';

  @override
  String get clearAppData => 'Gegevens wissen';

  @override
  String get clearAppDataDesc =>
      'Alle lokale Sked-gegevens definitief verwijderen en de app sluiten';

  @override
  String get clearAppDataConfirmTitle => 'Alle Sked-gegevens wissen?';

  @override
  String get clearAppDataConfirmMessage =>
      'Hiermee worden roosters, agenda’s, instellingen, schoolwebsites, lokale back-ups, herstelkopieën en de AI-API-sleutel definitief verwijderd. Daarna wordt Sked gesloten. Bestanden die je elders hebt geëxporteerd, worden niet verwijderd. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get clearAppDataAction => 'Gegevens wissen en sluiten';

  @override
  String get clearAppDataFailed =>
      'Niet alle lokale gegevens konden worden gewist. Sked blijft open zodat je het opnieuw kunt proberen.';

  @override
  String get clearAppDataExitFailed =>
      'Je lokale gegevens zijn gewist, maar Sked kon niet worden gesloten. Sluit de app handmatig voordat je deze opnieuw gebruikt.';

  @override
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'Parser: eigen ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Volledig privacybeleid bekijken';

  @override
  String get privacyAgreeAndContinue => 'Akkoord en doorgaan';

  @override
  String get privacyDecline => 'Weigeren';

  @override
  String get privacyDeclineWebHint =>
      'In deze browseromgeving kan de app de pagina niet voor je sluiten. Sluit dit tabblad of venster zelf als je niet akkoord gaat.';

  @override
  String get defaultPeriodTimeSetName => 'Standaardlestijden';

  @override
  String get periodTimeSetFallbackName => 'Lestijden';

  @override
  String get untitledTimetableName => 'Naamloos rooster';

  @override
  String get newTimetableName => 'Nieuw rooster';

  @override
  String get newPeriodTimeSetName => 'Nieuw lestijdenschema';

  @override
  String get emptyTimetableName => 'Leeg rooster';

  @override
  String importedPeriodTimeSetName(Object name) {
    return 'Lestijden van $name';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Het type van het importbestand komt niet overeen.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Deze versie van het importbestand wordt nog niet ondersteund.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Geen lestijden gevonden in het importbestand.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Selecteer minstens één rooster.';

  @override
  String get noExportableTimetableMessage =>
      'Er is geen rooster beschikbaar om te exporteren.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Selecteer precies één rooster om het huidige rooster te vervangen.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Er is geen huidig rooster om te vervangen.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Dit lestijdenschema wordt nog door $count rooster(s) gebruikt. Wijs deze roosters eerst een ander schema toe voordat je dit verwijdert.';
  }

  @override
  String get weekdayMonday => 'Maandag';

  @override
  String get weekdayTuesday => 'Dinsdag';

  @override
  String get weekdayWednesday => 'Woensdag';

  @override
  String get weekdayThursday => 'Donderdag';

  @override
  String get weekdayFriday => 'Vrijdag';

  @override
  String get weekdaySaturday => 'Zaterdag';

  @override
  String get weekdaySunday => 'Zondag';

  @override
  String get weekdayShortMonday => 'Ma';

  @override
  String get weekdayShortTuesday => 'Di';

  @override
  String get weekdayShortWednesday => 'Wo';

  @override
  String get weekdayShortThursday => 'Do';

  @override
  String get weekdayShortFriday => 'Vr';

  @override
  String get weekdayShortSaturday => 'Za';

  @override
  String get weekdayShortSunday => 'Zo';

  @override
  String get monthJanuary => 'Jan';

  @override
  String get monthFebruary => 'Feb';

  @override
  String get monthMarch => 'Mrt';

  @override
  String get monthApril => 'Apr';

  @override
  String get monthMay => 'Mei';

  @override
  String get monthJune => 'Jun';

  @override
  String get monthJuly => 'Jul';

  @override
  String get monthAugust => 'Aug';

  @override
  String get monthSeptember => 'Sep';

  @override
  String get monthOctober => 'Okt';

  @override
  String get monthNovember => 'Nov';

  @override
  String get monthDecember => 'Dec';

  @override
  String get semesterWeeksWholeTerm => 'Hele semester';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Weken $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Weken $value';
  }

  @override
  String get generalSchedule => 'Agenda';

  @override
  String get studentTimetable => 'Lesrooster';

  @override
  String get firstLaunchTitle => 'Kies je startmodus';

  @override
  String get firstLaunchSubtitle =>
      'Kies de werkruimte die je het meest gebruikt. Je kunt later van modus wisselen.';

  @override
  String get firstLaunchStudentDesc =>
      'Beheer roosters, vakken, weken, lestijden en import.';

  @override
  String get firstLaunchGeneralDesc =>
      'Beheer categorieën, evenementen, herinneringen en JSON / ICS-gegevens.';

  @override
  String get firstLaunchStartStudent => 'Starten met rooster';

  @override
  String get firstLaunchStartGeneral => 'Starten met agenda';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Door een startwerkruimte te kiezen, bevestig je dat je het ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Privacybeleid';

  @override
  String get firstLaunchPrivacyConsentAfter =>
      ' hebt gelezen en ermee akkoord gaat.';

  @override
  String get switchMode => 'Modus wisselen';

  @override
  String get generalScheduleComingSoon => 'Agenda binnenkort beschikbaar';

  @override
  String get switchToStudentTimetable => 'Naar het lesrooster';

  @override
  String get mySchedule => 'Mijn agenda';

  @override
  String get today => 'Vandaag';

  @override
  String get addEvent => 'Afspraak toevoegen';

  @override
  String get editEvent => 'Afspraak bewerken';

  @override
  String get eventTitle => 'Titel';

  @override
  String get eventTitleRequired => 'Voer een titel in';

  @override
  String get eventStartTime => 'Begintijd';

  @override
  String get eventEndTime => 'Eindtijd';

  @override
  String get eventDate => 'Datum';

  @override
  String get eventTime => 'Tijd';

  @override
  String get eventNotes => 'Notities';

  @override
  String get eventColor => 'Kleur';

  @override
  String get eventRecurrence => 'Herhaling';

  @override
  String get recurrenceNone => 'Wordt niet herhaald';

  @override
  String get recurrenceWeekly => 'Wekelijks';

  @override
  String get recurrenceEndDate => 'Einddatum';

  @override
  String get recurrenceNoEndDate => 'Geen einddatum';

  @override
  String get recurrenceSetEndDate => 'Instellen';

  @override
  String get recurrenceChangeEndDate => 'Wijzigen';

  @override
  String get repeatsWeekly => 'Wordt wekelijks herhaald';

  @override
  String recurrenceUntil(Object date) {
    return 'Tot $date';
  }

  @override
  String get switchToGeneralSchedule => 'Naar de agenda';

  @override
  String get generalDisplaySettings => 'Algemene weergave-instellingen';

  @override
  String get generalDisplaySettingsDesc =>
      'Weergaven, werkbalk, datumnotatie en snel toevoegen';

  @override
  String get closePopupOnOutsideTap => 'Popup sluiten door erbuiten te tikken';

  @override
  String get showGridLines => 'Rasterlijnen tonen';

  @override
  String get generalScheduleImportExport =>
      'Categorieën importeren en exporteren';

  @override
  String get generalScheduleImportExportDesc =>
      'Agendacategorieën importeren of delen';

  @override
  String get importGeneralSchedules => 'Categorieën importeren';

  @override
  String get importGeneralSchedulesDesc =>
      'Categorieën uit een JSON-bestand lezen';

  @override
  String get shareGeneralSchedules => 'Categorieën delen';

  @override
  String get shareGeneralSchedulesDesc => 'Categorieën delen als JSON-bestand';

  @override
  String get saveGeneralSchedules => 'Categorieën opslaan';

  @override
  String get saveGeneralSchedulesDesc => 'Categorieën opslaan als JSON-bestand';

  @override
  String get selectSchedulesToExport => 'Kies categorieën om te exporteren';

  @override
  String get selectSchedulesToImport => 'Kies categorieën om te importeren';

  @override
  String generalScheduleEventCount(int count) {
    return 'Afspraken: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return '$count categorieën geïmporteerd';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'De import toevoegen als nieuwe categorie of een bestaande categorie vervangen?';

  @override
  String get addAsNewSchedule => 'Als nieuwe categorie toevoegen';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Selecteer minstens één categorie.';

  @override
  String get noExportableScheduleMessage =>
      'Er is geen categorie beschikbaar om te exporteren.';

  @override
  String get noSchedulesInImportMessage =>
      'Het importbestand bevat geen categorieën.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Kies precies één geïmporteerde categorie voor de vervanging.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'De geselecteerde categorie om te vervangen is niet beschikbaar.';

  @override
  String get calendars => 'Categorieën';

  @override
  String get calendar => 'Categorie';

  @override
  String get viewWeek => 'Week';

  @override
  String get viewDay => 'Dag';

  @override
  String get viewList => 'Lijst';

  @override
  String get viewMonth => 'Maand';

  @override
  String visibleCategoryCount(int count) {
    return '$count categorieën';
  }

  @override
  String get noVisibleCategories => 'Geen zichtbare categorieën';

  @override
  String get selectCategoryToReplace => 'Kies de te vervangen categorie';

  @override
  String get replaceCategory => 'Categorie vervangen';

  @override
  String get deleteEventTitle => 'Afspraak verwijderen';

  @override
  String get deleteEventConfirmation =>
      'Deze afspraak wordt definitief verwijderd.';

  @override
  String get deleteRecurringEventTitle => 'Terugkerende afspraak verwijderen';

  @override
  String get eventDuplicated => 'Afspraak gedupliceerd';

  @override
  String get searchEvents => 'Afspraken zoeken';

  @override
  String get clearSearch => 'Zoekopdracht wissen';

  @override
  String get filterByColor => 'Filteren op kleur';

  @override
  String get allColors => 'Alle kleuren';

  @override
  String upcomingEventsCount(int count) {
    return 'Aankomend: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Verlopen: $count';
  }

  @override
  String get allDay => 'Hele dag';

  @override
  String get collapseAllDayTimeline => 'Dagvullende afspraken samenvouwen';

  @override
  String get expandAllDayTimeline => 'Dagvullende afspraken uitvouwen';

  @override
  String allDayEventsCount(int count) {
    return '$count dagvullende afspraken';
  }

  @override
  String moreEvents(int count) {
    return '+$count meer';
  }

  @override
  String get noMatchingEvents => 'Geen overeenkomende afspraken';

  @override
  String get noUpcomingEvents => 'Geen aankomende afspraken';

  @override
  String get addCalendar => 'Categorie toevoegen';

  @override
  String get newCalendar => 'Nieuwe categorie';

  @override
  String get hideCalendar => 'Categorie verbergen';

  @override
  String get showCalendar => 'Categorie tonen';

  @override
  String get rename => 'Naam wijzigen';

  @override
  String get renameCalendar => 'Categorienaam wijzigen';

  @override
  String get name => 'Naam';

  @override
  String get deleteCalendar => 'Categorie verwijderen';

  @override
  String deleteCalendarMessage(Object name) {
    return '‘$name’ verwijderen?';
  }

  @override
  String get deleteThisOccurrence => 'Deze herhaling verwijderen';

  @override
  String get deleteFutureOccurrences =>
      'Deze en volgende herhalingen verwijderen';

  @override
  String get deleteAllOccurrences => 'Hele reeks verwijderen';

  @override
  String get duplicateEvent => 'Dupliceren';

  @override
  String get repeatsDaily => 'Wordt dagelijks herhaald';

  @override
  String get repeatsMonthly => 'Wordt maandelijks herhaald';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Wordt elke $interval $unit herhaald';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count keer';
  }

  @override
  String get recurrenceDaily => 'Dagelijks';

  @override
  String get recurrenceMonthly => 'Maandelijks';

  @override
  String get recurrenceCustom => 'Aangepast';

  @override
  String get recurrenceEvery => 'Elke';

  @override
  String get recurrenceUnit => 'Eenheid';

  @override
  String get recurrenceDays => 'Dagen';

  @override
  String get recurrenceWeeks => 'Weken';

  @override
  String get recurrenceMonths => 'Maanden';

  @override
  String get recurrenceRepeatCount => 'Aantal herhalingen';

  @override
  String get recurrenceNoLimit => 'Geen limiet';

  @override
  String get recurrencePositiveNumber => 'Voer een positief getal in';

  @override
  String get clearEndDate => 'Einddatum wissen';

  @override
  String get pickDate => 'Datum kiezen';

  @override
  String get pickTime => 'Tijd kiezen';

  @override
  String get reminder => 'Herinnering in de app';

  @override
  String get reminderAtStart => 'Bij aanvang';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min van tevoren';
  }

  @override
  String get reminderHourBefore => '1 uur van tevoren';

  @override
  String get reminderDayBefore => '1 dag van tevoren';

  @override
  String get markReminderHandled => 'Als afgehandeld markeren';

  @override
  String get restoreReminder => 'App-herinnering herstellen';

  @override
  String get reminderHandled => 'App-herinnering als afgehandeld gemarkeerd';

  @override
  String get reminderRestored => 'App-herinnering hersteld';

  @override
  String get reminderUpcoming => 'Aankomend';

  @override
  String get reminderOverdue => 'Verlopen';

  @override
  String get generalFitWeekColumnsToWidth =>
      'Weekweergave aan scherm aanpassen';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Toon de hele week in compacte lay-outs. Schakel uit om horizontaal te scrollen. Aangepaste perioden van meer dan 7 dagen blijven scrollbaar.';

  @override
  String get showWeekends => 'Weekenden tonen';

  @override
  String get startHour => 'Beginuur';

  @override
  String get endHour => 'Einduur';

  @override
  String get timeGridDensity => 'Dichtheid van het tijdraster';

  @override
  String get timeGridHourHeight => 'Hoogte van een uurrij';

  @override
  String get timeGridHourHeightHint =>
      'Past de verticale schaal van de dag- en weekweergave aan zonder het rasterinterval van 15, 30 of 60 minuten te wijzigen.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'JSON-bestand importeren';

  @override
  String get pasteJson => 'JSON plakken';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Categorieën importeren uit gekopieerde JSON';

  @override
  String get importIcsFile => 'ICS-bestand importeren';

  @override
  String get importIcsFileDesc => 'Afspraken lezen uit een .ics-agendabestand';

  @override
  String get pasteIcs => 'ICS plakken';

  @override
  String get pasteIcsDesc => 'Afspraken importeren uit gekopieerde agendatekst';

  @override
  String get copyJson => 'JSON kopiëren';

  @override
  String get copyJsonDesc =>
      'Geselecteerde categorieën kopiëren als JSON-tekst';

  @override
  String get shareIcs => 'ICS delen';

  @override
  String get shareIcsDesc => 'Geselecteerde agenda’s delen als .ics';

  @override
  String get saveIcs => 'ICS opslaan';

  @override
  String get saveIcsDesc => 'Geselecteerde agenda’s opslaan als .ics';

  @override
  String get copyIcs => 'ICS kopiëren';

  @override
  String get copyIcsDesc => 'Geselecteerde agenda’s kopiëren als ICS-tekst';

  @override
  String get importIcs => 'ICS importeren';

  @override
  String get icsContent => 'ICS-inhoud';

  @override
  String get pasteIcsContentHint =>
      'Plak hier de inhoud die begint met BEGIN:VCALENDAR';

  @override
  String importIcsPreviewPrompt(int count) {
    return '$count afspraken gevonden. Toevoegen als nieuwe categorie of een bestaande categorie vervangen?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return '$count categorieën geïmporteerd met $warningCount meldingen';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Een afspraak zonder begintijd is overgeslagen.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Een afspraak met een niet-ondersteunde begintijd is overgeslagen.';

  @override
  String get importWarningAdjustedEnd =>
      'De eindtijd van een afspraak is aangepast omdat deze niet na de begintijd lag.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Niet-ondersteunde ICS-velden zijn aan de notities toegevoegd: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Niet-ondersteunde herhalingsfrequentie genegeerd: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs => 'Kies agenda’s om als ICS te kopiëren';

  @override
  String get selectCalendarsToExportIcs =>
      'Kies agenda’s om als ICS te exporteren';

  @override
  String get exportIcsText => 'ICS-tekst exporteren';

  @override
  String get exportJsonText => 'JSON-tekst exporteren';

  @override
  String get dataRestoredFromBackupNotice =>
      'De app-gegevens zijn uit de vorige back-up hersteld omdat het hoofdbestand niet kon worden geladen.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Zowel het hoofdgegevensbestand als de back-up zijn beschadigd. De app gebruikt nu een nieuwe beginstatus.';

  @override
  String get dataRecoveryCorruptTitle => 'Je gegevens moeten worden hersteld';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked kon het hoofdgegevensbestand en de back-up ervan niet lezen. Voordat schrijven werd geblokkeerd, zijn beschermde kopieën gemaakt.';

  @override
  String get dataRecoveryIoFailureTitle => 'Opslag niet beschikbaar';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked heeft momenteel geen toegang tot de lokale opslag. Controleer de opslagtoegang en de beschikbaarheid van het apparaat en probeer het opnieuw. Bestaande gegevens worden niet overschreven.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Werk Sked bij om deze gegevens te openen';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Deze gegevens zijn gemaakt met een nieuwere versie van Sked. Werk de app bij voordat je het opnieuw probeert. Opnieuw beginnen met lege gegevens is uitgeschakeld om ze te beschermen.';

  @override
  String get dataRecoveryRetryAction => 'Opnieuw proberen';

  @override
  String get dataRecoveryArtifactsHint =>
      'Herstelbestanden en betrokken opslaglocaties staan hieronder. Wijzig geen bestanden totdat je gegevens zijn hersteld.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Herstelbestanden en opslaglocaties tonen';

  @override
  String get dataRecoveryStartFreshAction => 'Met nieuwe gegevens beginnen';

  @override
  String get dataRecoveryStartFreshConfirmTitle =>
      'Met nieuwe gegevens beginnen?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'De beschermde kopieën blijven bewaard, maar Sked maakt een nieuw lokaal gegevensbestand. Ga alleen verder als je het herstel niet eerst opnieuw wilt proberen.';

  @override
  String get previousMonth => 'Vorige maand';

  @override
  String get nextMonth => 'Volgende maand';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'Bezig';

  @override
  String get deleteCourseTitle => 'Vak verwijderen';

  @override
  String get deleteCourseMessage => 'Dit vak verwijderen?';

  @override
  String get showLunarCalendar => 'Maankalender tonen';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count afspraken';
  }

  @override
  String get defaultView => 'Standaardweergave';

  @override
  String get generalDefaultViewSection => 'Bij het opstarten';

  @override
  String get generalViewSwitchBehavior => 'Knop voor weergavewissel';

  @override
  String get settingsWorkspaceMode => 'Actieve werkruimte';

  @override
  String get hideHomeWorkspaceNavigation => 'Werkruimtenavigatie verbergen';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Verberg de werkruimtenavigatie. Wisselen kan nog steeds via het werkruimtemenu op het hoofdscherm.';

  @override
  String get generalDateLabelFormat => 'Notatie van het datumlabel';

  @override
  String get generalDateLabelFormatLocalized => 'Lokaal (jul 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Schuine strepen (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Werkbalkindeling';

  @override
  String get toolbarNavigationSection => 'Werkbalknavigatie';

  @override
  String get toolbarNavigationHiddenBehavior => 'Verborgen onderdelen';

  @override
  String get toolbarNavigationRemove => 'Volledig verbergen';

  @override
  String get toolbarNavigationMore => 'Naar Meer verplaatsen';

  @override
  String get toolbarNavigationReorder => 'Werkbalkonderdelen herschikken';

  @override
  String get toolbarNavigationVisibility => 'Werkbalkonderdeel tonen';

  @override
  String get toolbarNavigationTimetable => 'Roosterkeuze';

  @override
  String get toolbarNavigationWeek => 'Weekkeuze';

  @override
  String get toolbarNavigationView => 'Weergavewissel';

  @override
  String get toolbarNavigationCategory => 'Categoriekeuze';

  @override
  String get toolbarNavigationDate => 'Datumkeuze';

  @override
  String get generalToolbarWidthPolicy => 'Ruimteverdeling van de werkbalk';

  @override
  String get generalToolbarWidthContent => 'Automatische verdeling';

  @override
  String get generalToolbarWidthBalanced => 'Gebalanceerd';

  @override
  String get generalToolbarWidthCalendarPriority => 'Voorrang voor categorieën';

  @override
  String get generalToolbarWidthDatePriority => 'Voorrang voor datum';

  @override
  String get generalViewSwitchCycle => 'Weergaven achtereenvolgens wisselen';

  @override
  String get generalViewSwitchMenu => 'Weergavemenu openen';

  @override
  String get generalViewSwitchTooltip => 'Weergave wisselen';

  @override
  String get generalViewSwitchMenuTooltip => 'Weergave kiezen';

  @override
  String get generalViewLongPressTodayHint =>
      'Houd ingedrukt om naar vandaag te gaan';

  @override
  String get generalScheduleDisplaySection => 'Agendaweergave';

  @override
  String get generalTimeGridSection => 'Tijdraster';

  @override
  String get generalPopupSection => 'Popupgedrag';

  @override
  String get quickActionsSection => 'Snelle acties';

  @override
  String get showAddCourseFab =>
      'Zwevende knop voor het toevoegen van vakken tonen';

  @override
  String get showAddCourseFabHint =>
      'Toon of verberg de zwevende knop om vakken toe te voegen rechtsonder in het rooster.';

  @override
  String get showAddEventFab =>
      'Zwevende knop voor het toevoegen van afspraken tonen';

  @override
  String get showAddEventFabHint =>
      'Toon of verberg de zwevende knop om afspraken toe te voegen rechtsonder in de agenda.';

  @override
  String get enableLongPressAddCourse =>
      'Leeg raster lang indrukken om vakken toe te voegen';

  @override
  String get enableLongPressAddCourseHint =>
      'Houd een leeg gebied in het rooster ingedrukt om een vak toe te voegen.';

  @override
  String get enableLongPressAddEvent =>
      'Leeg raster lang indrukken om afspraken toe te voegen';

  @override
  String get enableLongPressAddEventHint =>
      'Houd in de dag- of weekweergave een leeg gebied in het tijdraster ingedrukt om een afspraak toe te voegen.';

  @override
  String get developerModeTitle => 'Ontwikkelaarsmodus';

  @override
  String get developerModeDescription =>
      'Hulpmiddelen om volledige voorbeeldgegevens toe te voegen voor controle van weergave en interactie.';

  @override
  String get developerSampleLanguage => 'Taal van voorbeeldgegevens';

  @override
  String get developerSampleChinese => 'Chinees';

  @override
  String get developerSampleEnglish => 'Engels';

  @override
  String get developerSampleDataDescription =>
      'Voegt één rooster en een set categorieën en afspraken toe zonder bestaande gegevens te vervangen.';

  @override
  String get developerAddSampleData => 'Voorbeeldgegevens toevoegen';

  @override
  String get developerSampleDataAdded =>
      'Voorbeeldrooster en -afspraken toegevoegd.';

  @override
  String get developerModeLongPressHint =>
      'Houd 3 seconden ingedrukt om de ontwikkelaarsmodus te openen';

  @override
  String get developerNotificationDiagnostics => 'Meldingendiagnostiek';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Controleer de bezorgstatus op Android, bouw het bestaande herinneringsplan opnieuw op en verstuur veilige testmeldingen via de normale meldingsservice van Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Meldingendiagnostiek is alleen beschikbaar op Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Meldingendiagnostiek is beschikbaar zodra de agendacoördinator is gestart.';

  @override
  String get developerNotificationRefresh => 'Diagnostiek vernieuwen';

  @override
  String get developerNotificationSystemStatus =>
      'Systeemtoestemming voor meldingen';

  @override
  String get developerNotificationPermissionAllowed => 'Toegestaan';

  @override
  String get developerNotificationPermissionBlocked => 'Geblokkeerd';

  @override
  String get developerNotificationExactAlarm => 'Exacte alarmen';

  @override
  String get developerNotificationExactAlarmAllowed => 'Toegestaan';

  @override
  String get developerNotificationExactAlarmBlocked => 'Niet toegestaan';

  @override
  String get developerNotificationPlan => 'Meldingsplan voor de agenda';

  @override
  String get developerNotificationCoverage => 'Dekking';

  @override
  String get developerNotificationCoverageReady =>
      'Alle bekende herinneringen met een eindig aantal herhalingen zijn rechtstreeks ingepland';

  @override
  String get developerNotificationCoverageRenewable =>
      'Herhalende herinneringen worden waar mogelijk opnieuw ingepland voor dekking op lange termijn';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'De capaciteit voor rechtstreekse alarmen is bereikt; latere herinneringen worden waar mogelijk opnieuw ingepland';

  @override
  String get developerNotificationCoverageBlocked =>
      'Niet aan de voorwaarden voor nauwkeurige bezorging voldaan';

  @override
  String get developerNotificationCoverageFailed =>
      'De laatste synchronisatie van herinneringen is mislukt';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled rechtstreekse alarmen / capaciteit $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled ingepland, $planned gepland';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Laatste fout: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Meldingsplan opnieuw opbouwen';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Meldingsplan opnieuw opgebouwd.';

  @override
  String get developerNotificationTestChannel => 'Testkanaal';

  @override
  String get developerNotificationTestCourse => 'Herinneringen voor vakken';

  @override
  String get developerNotificationTestSchedule => 'Agendaherinneringen';

  @override
  String get developerNotificationImmediateTest =>
      'Direct een testmelding versturen';

  @override
  String get developerNotificationThirtySecondTest =>
      'Achtergrondtest over 30 seconden inplannen';

  @override
  String get developerNotificationImmediateQueued =>
      'Directe testmelding verstuurd.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Achtergrondtest ingepland over 30 seconden.';

  @override
  String get developerNotificationAppSwitch =>
      'Herinneringsschakelaar in de app';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Ingeschakeld voor gewone herinneringen';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Uitgeschakeld voor gewone herinneringen; ontwikkelaarstests blijven beschikbaar';

  @override
  String get developerNotificationTimeZone => 'Lokale tijdzone';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Nog niet aangemaakt. Een ontwikkelaarstest maakt het kanaal aan.';

  @override
  String get developerNotificationChannelEnabledState => 'Ingeschakeld';

  @override
  String get developerNotificationChannelBlockedState => 'Geblokkeerd';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Belangrijkheid: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Belangrijkheid niet beschikbaar';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending in behandeling / $active actief';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'laatst door het systeem getoond om $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Nog geen herberekening vastgelegd.';

  @override
  String get developerNotificationNextReminder => 'Volgende echte herinnering';

  @override
  String get developerNotificationNoPendingReminder =>
      'Geen toekomstige herinnering in het huidige plan';

  @override
  String get developerNotificationNextMaintenance => 'Volgend onderhoud';

  @override
  String get developerNotificationNextRenewal =>
      'Volgende poging tot opnieuw inplannen';

  @override
  String get developerNotificationNoMaintenance => 'Niet ingepland';

  @override
  String get developerNotificationTruncation => 'Afkapping van het plan';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count weggelaten vanwege de planlimiet';
  }

  @override
  String get developerNotificationLastReconciliation => 'Laatste herberekening';

  @override
  String get developerNotificationLastSynchronization =>
      'Laatste synchronisatie van herinneringen';

  @override
  String get developerNotificationLateRecovery =>
      'Herstel van late herinneringen';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count herinnering(en) zijn na het oorspronkelijke tijdstip alsnog bezorgd';
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
  String get developerNotificationReconcileOriginForeground => 'Voorgrond';

  @override
  String get developerNotificationReconcileOriginBackground => 'Achtergrond';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Volledige herberekening';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Onderhoud';

  @override
  String get developerNotificationReconcileModeRecovery => 'Herstel';

  @override
  String get developerNotificationRunRecovery => 'Herinneringen herstellen';

  @override
  String get developerNotificationRecoveryComplete =>
      'Herstel van herinneringen voltooid';

  @override
  String get developerNotificationReconcileResultSuccess => 'Geslaagd';

  @override
  String get developerNotificationReconcileResultSkipped => 'Overgeslagen';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Geblokkeerd totdat aan alle voorwaarden voor nauwkeurige bezorging is voldaan';

  @override
  String get developerNotificationReconcileResultFailed => 'Mislukt';

  @override
  String get developerNotificationBackgroundLimits =>
      'Achtergrondbeperkingen van de fabrikant';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Achtergrondbeperkingen van de fabrikant kunnen de bezorging beïnvloeden.';

  @override
  String get developerNotificationAutostart =>
      'Achtergrondstart van de fabrikant';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Fabrikant $vendor; er is een ingang naar de fabrikantinstellingen beschikbaar. Android kan de toestemmingsstatus niet weergeven.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Fabrikant $vendor; de appgegevens worden als alternatief geopend. Android kan de toestemmingsstatus niet weergeven.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Geen ingang naar de achtergrondinstellingen van de fabrikant beschikbaar.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Laatst geopend doel: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'fabrikantinstellingen';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'appgegevens';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'geen';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Herstelbeperkingen na opnieuw opstarten';

  @override
  String get developerNotificationRebootBoundary =>
      'Herstel begint na de eerste ontgrendeling; een gedwongen gestopte app kan zichzelf niet starten.';

  @override
  String get developerNotificationTestChecking =>
      'Tests zijn niet beschikbaar terwijl de meldingsstatus wordt gecontroleerd.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Tests zijn niet beschikbaar omdat systeemmeldingen zijn geblokkeerd.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Tests zijn niet beschikbaar omdat het geselecteerde meldingskanaal is geblokkeerd.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Beheerd via de meldingsinstellingen van Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Niet van toepassing op Windows';

  @override
  String get developerNotificationWindowsIdentity => 'Windows-pakketidentiteit';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX-identiteit beschikbaar; actieve meldingskaarten kunnen worden verwijderd';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Installeer de MSIX-versie om actieve meldingskaarten betrouwbaar te verwijderen';

  @override
  String get collapseWorkspaceNavigation => 'Werkruimtenavigatie inklappen';

  @override
  String get expandWorkspaceNavigation => 'Werkruimtenavigatie uitklappen';

  @override
  String get schoolWebImportExitBrowser => 'Ingebouwde browser sluiten';

  @override
  String get schoolWebImportEditAddress => 'Adres bewerken';

  @override
  String get schoolWebImportAddressLabel => 'Webadres';

  @override
  String get schoolWebImportOpenAddress => 'Openen';

  @override
  String get schoolWebImportAddressInvalid =>
      'Voer een HTTP- of HTTPS-adres met een host in.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Deze webpagina heeft een nieuw venster aangevraagd dat niet op dit apparaat kan worden geopend.';

  @override
  String get schoolWebImportSecureConnection => 'Beveiligde verbinding';

  @override
  String get schoolWebImportInsecureConnection => 'Onveilige verbinding';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Aanmelden bij de school openen?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Bij aanmelden bij de school kunnen aanmeldgegevens via formulieren of serveromleidingen naar de school en haar aanmeldproviders worden verzonden. Android kan niet elke dergelijke overdracht onderbreken voor een afzonderlijke bevestiging van de bestemming. Ga alleen door als u hen voor deze importsessie vertrouwt:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Onveilige schoolaanmelding openen?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Deze schoolaanmelding gebruikt HTTP. Iedereen die deze verbinding kan volgen of wijzigen, kan uw aanmeldgegevens en de pagina-inhoud lezen of veranderen. Ga alleen door als u dit risico accepteert voor:\n\n$origin';
  }

  @override
  String get notificationSettingsSection => 'Herinneringen en meldingen';

  @override
  String get notificationCoverage => 'Dekking van herinneringen';

  @override
  String get notificationCoverageRenewable =>
      'Herhalende afspraken zonder einddatum worden op de achtergrond opnieuw ingepland voor dekking op lange termijn.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android kan maximaal $capacity herinneringen rechtstreeks inplannen; latere herinneringen worden vooraf opnieuw ingepland.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Herinneringen en meldingen inschakelen';

  @override
  String get notificationSettingsEnabledHint =>
      'Plant alleen meldingen voor items met een herinnering. Stel hieronder een standaardherinnering in voor vakken die deze overnemen.';

  @override
  String get notificationPrecisionLimitations =>
      'Herinneringen hangen af van systeemrechten en achtergrondprocessen. Uitschakelen, tijdwijzigingen of systeembeperkingen kunnen ze vertragen.';

  @override
  String get notificationSettingsEnabledSummary => 'Ingeschakeld';

  @override
  String get notificationSettingsDisabledSummary => 'Uitgeschakeld';

  @override
  String get notificationDefaultsSection => 'Standaardherinneringen';

  @override
  String get notificationCourseDefaultReminder =>
      'Standaardherinnering voor vakken';

  @override
  String get notificationGeneralDefaultReminder =>
      'Standaardherinnering voor de agenda';

  @override
  String get notificationReminderOff => 'Geen herinnering';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minuten van tevoren';
  }

  @override
  String get notificationPermission => 'Toestemming voor meldingen';

  @override
  String get notificationPermissionGranted => 'Toegestaan door het systeem';

  @override
  String get notificationPermissionDenied => 'Geblokkeerd door het systeem';

  @override
  String get notificationPermissionChecking => 'Toestemming controleren…';

  @override
  String get notificationPermissionRequest => 'Toestemming aanvragen';

  @override
  String get notificationPermissionOpenSettings => 'Systeeminstellingen openen';

  @override
  String get notificationPermissionRequestFailed =>
      'Kan de toestemming voor meldingen niet uitlezen. Probeer het opnieuw.';

  @override
  String get notificationExactAlarm => 'Toestemming voor exacte alarmen';

  @override
  String get notificationExactAlarmAllowed => 'Toegestaan door het systeem';

  @override
  String get notificationExactAlarmRequired =>
      'Vereist voor nauwkeurige herinneringstijden';

  @override
  String get notificationExactAlarmRequest => 'Exacte alarmen toestaan';

  @override
  String get notificationBatteryOptimization => 'Batterijoptimalisatie';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Uitgezonderd van batterijoptimalisatie op Android';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Voor nauwkeurige herinneringen moet Sked worden uitgezonderd van batterijoptimalisatie op Android';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Instellingen voor batterijoptimalisatie openen';

  @override
  String get notificationAutostart => 'Achtergrondstart van de fabrikant';

  @override
  String get notificationAutostartVendorHint =>
      'Sta automatisch starten of uitvoeren op de achtergrond toe zodat herinneringen na opnieuw opstarten kunnen worden hersteld.';

  @override
  String get notificationAutostartFallbackHint =>
      'Open de appgegevens van Sked en sta uitvoeren op de achtergrond toe. Android kan deze fabrikantinstelling niet controleren.';

  @override
  String get notificationAutostartUnavailable =>
      'Geen pagina met fabrikantinstellingen gevonden. Controleer de appgegevens van Sked handmatig.';

  @override
  String get notificationAutostartRequest =>
      'Achtergrondinstellingen van de fabrikant openen';

  @override
  String get notificationAutostartOpenFailed =>
      'Kan de achtergrondinstellingen van de fabrikant niet openen. Controleer de appgegevens van Sked handmatig.';

  @override
  String get notificationLockScreenTitles =>
      'Titels op het vergrendelscherm tonen';

  @override
  String get notificationLockScreenTitlesHint =>
      'Als dit is uitgeschakeld, blijven de meldingsdetails verborgen op het vergrendelscherm.';

  @override
  String get notificationWidgets => 'Widgets op het startscherm';

  @override
  String get notificationWidgetsDesc =>
      'Vernieuw Sked-widgets en lees hoe je er een toevoegt vanuit het startscherm.';

  @override
  String get notificationWidgetsDialogTitle => 'Een Sked-widget toevoegen';

  @override
  String get notificationWidgetsDialogMessage =>
      'Houd een lege plek op het startscherm van je apparaat ingedrukt, kies Widgets en voeg een Sked-widget toe. De widget toont je volgende lessen of afspraken.';

  @override
  String get notificationWidgetsRefresh => 'Widgets vernieuwen';

  @override
  String get notificationWidgetsRefreshed => 'Widgets vernieuwd';

  @override
  String get notificationPlatformUnsupported =>
      'Dit platform ondersteunt geen systeemeigen meldingen.';

  @override
  String get workspaceFeatures => 'Functiebeheer';

  @override
  String get workspaceBoth => 'Lesrooster en agenda';

  @override
  String get workspaceOnlyStudent => 'Alleen lesrooster';

  @override
  String get workspaceOnlyGeneral => 'Alleen agenda';

  @override
  String get workspaceDisableTitle => 'Deze werkruimte uitschakelen?';

  @override
  String get workspaceDisableMessage =>
      'Gegevens en voorkeuren blijven bewaard. Functies en herinneringen stoppen totdat je de werkruimte hier weer inschakelt.';

  @override
  String get workspaceEnableHint =>
      'Kies de functies die je gebruikt. Er moet er minstens één actief blijven.';

  @override
  String get workspaceLastRequired =>
      'Er moet minstens één werkruimte actief blijven.';

  @override
  String get workspaceReminderCleanupFailed =>
      'De werkruimte is uitgeschakeld, maar herinneringen konden niet worden verwijderd. Probeer het meldingsherstel opnieuw.';

  @override
  String get settingsSearch => 'Instellingen zoeken';

  @override
  String get settingsNoResults => 'Geen overeenkomende instellingen';

  @override
  String get settingsDataPrivacy => 'Gegevens en privacy';

  @override
  String get workspacePreferences => 'Weergave en bediening';

  @override
  String get workspaceManage => 'Beheren';

  @override
  String get selectedDayAgenda => 'Geselecteerde dag';

  @override
  String get notificationTroubleshooting => 'Machtigingen en probleemoplossing';

  @override
  String get settingsConnection => 'Verbinding';

  @override
  String get settingsAdvanced => 'Geavanceerd';

  @override
  String get unsavedChangesMessage =>
      'Je hebt niet-opgeslagen wijzigingen. Verwerpen en sluiten?';

  @override
  String get backupWorkspaceSelection =>
      'De volledige back-up bevat gegevens en de selectie van actieve werkruimten.';

  @override
  String get assistantLayoutPreview => 'AI · Voorbeeld van de indeling';

  @override
  String get assistantSelectionContext =>
      'Gebruikt de huidige selectie als context';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Conceptbericht';

  @override
  String get assistantPreviewNoSend =>
      'Alleen een voorbeeld van de indeling. Er wordt niets verstuurd of gewijzigd.';

  @override
  String get resizePanel => 'Paneelgrootte aanpassen';

  @override
  String get minimizeWindow => 'Minimaliseren';

  @override
  String get maximizeWindow => 'Maximaliseren';

  @override
  String get restoreWindow => 'Venster herstellen';

  @override
  String get closeWindow => 'Venster sluiten';

  @override
  String get courseSystemReminder => 'Systeemherinnering';

  @override
  String courseReminderInherit(String reminder) {
    return 'Standaard gebruiken ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Systeemherinneringen staan uit in de meldingsinstellingen. Deze voorkeur voor het vak kan wel worden opgeslagen.';

  @override
  String get courseReminderDefaultOff =>
      'Er is geen standaardherinnering voor vakken ingesteld. Kies hier een aangepaste herinnering of stel een standaard in via de meldingsinstellingen.';

  @override
  String get courseReminderDeliveryHint =>
      'Deze voorkeur wordt bij het vak opgeslagen. De bezorging hangt af van de systeemtoestemming voor meldingen en de achtergrondbeperkingen.';

  @override
  String get courseReminderPermissionUnknown =>
      'De status van systeemmeldingen is nog niet gecontroleerd. Controleer de meldingsinstellingen voordat je op herinneringen vertrouwt.';

  @override
  String get courseReminderMinutesLabel => 'Minuten voor de les';

  @override
  String get exportAction => 'Exporteren';

  @override
  String get datePickerSelectWeek => 'Week selecteren';

  @override
  String get datePickerSelectMonth => 'Maand selecteren';

  @override
  String get generalDateLabelFormatDescription =>
      'Geldt voor datumnavigatie op desktops en kleinere schermen.';

  @override
  String get dateRangeTitle => 'Datumbereik kiezen';

  @override
  String get dateRangeCustom => 'Aangepast';

  @override
  String get dateRangeChooseStart => 'Kies de begindatum';

  @override
  String get dateRangeChooseEnd => 'Kies de einddatum';

  @override
  String get dateRangeLimit =>
      'Selecteer 1–14 dagen, inclusief de begin- en einddatum.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagen',
      one: '1 dag',
    );
    return 'Aangepast · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Kiezen met scrollwielen';

  @override
  String get courseReminderUseDefault => 'Standaard gebruiken';

  @override
  String get courseReminderInvalidMinutes =>
      'Voer een geheel aantal minuten in, nul of meer.';

  @override
  String get generalCustomColumnWidth =>
      'Kolombreedte in de aangepaste weergave';

  @override
  String get generalCustomColumnWidthAuto => 'Automatisch';

  @override
  String get generalCustomColumnWidthManual => 'Minimale breedte';

  @override
  String get generalCustomColumnWidthMinimum => 'Minimale breedte per dag';

  @override
  String get generalCustomColumnWidthHint =>
      'Alle datums gebruiken dezelfde minimale breedte. Kolommen vullen de beschikbare ruimte of kunnen horizontaal worden gescrold. Geldt alleen voor de aangepaste weergave.';

  @override
  String get settingsAppearanceLanguage => 'Uiterlijk en taal';

  @override
  String get settingsAppearanceDetails => 'Kleuren en randen';

  @override
  String get monthNoEvents => 'Geen afspraken op deze dag';

  @override
  String get settingsOverview => 'Overzicht';

  @override
  String get settingsThemeTarget => 'Thema voor';

  @override
  String get settingsColorMode => 'Kleurmodus';

  @override
  String get settingsNotificationPreferences => 'Herinneringsvoorkeuren';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Standaardherinneringen, toestemmingen en betrouwbaarheid';

  @override
  String get settingsFeaturesSummary => 'Werkruimten en navigatie';

  @override
  String get settingsPrivacySummary =>
      'Privacybeleid en lokale gegevens wissen';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lesuren',
      one: '1 lesuur',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Lesuur';

  @override
  String get periodTimesDurationColumn => 'Duur';

  @override
  String get periodTimesGapColumn => 'Pauze';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Wachten op opslaan…';

  @override
  String get periodTimesSaveFailed => 'Niet opgeslagen · Opslaan mislukt';

  @override
  String get periodTimesInvalidStatus =>
      'Niet opgeslagen · Corrigeer de gemarkeerde tijden';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked kon niet bevestigen of de laatste opslagbewerking is teruggedraaid. Schrijven is gepauzeerd en herstelkopieën zijn bewaard. Controleer de opslag en probeer opnieuw te laden.';

  @override
  String get settingsPanelDisplayMode => 'Paneelweergave';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Gedeeld door lesroosters en agenda’s';

  @override
  String get settingsPanelDisplayOverlay => 'Overlappend';

  @override
  String get settingsPanelDisplaySideBySide => 'Naast elkaar';

  @override
  String get settingsPanelDisplayAutomatic => 'Automatisch';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Overlapt de rechterkant zonder de kalenderbreedte te wijzigen.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Geeft voorkeur aan naast elkaar; overlapt alleen als de kalender te smal wordt.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Toont panelen naast elkaar als de kalender leesbaar blijft, anders overlappend.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Als je Instellingen of Werkruimte uitschakelt in de werkbalk, wordt deze naar Meer verplaatst. Meer kan niet worden verborgen zolang het essentiële acties bevat. Wisselen tussen werkruimten verschijnt alleen als de onderste navigatie verborgen is en meerdere werkruimten zijn ingeschakeld.';

  @override
  String get reminderEnded => 'Afgelopen';

  @override
  String get reminderAutoCloseHint =>
      'Sluit na 10 seconden. Gebruik het paneel om het open te houden.';

  @override
  String get showReminderIndependently => 'Afzonderlijk openen';

  @override
  String get categoryManagerTitle => 'Categorieën beheren';

  @override
  String get categoryHidden => 'Verborgen';

  @override
  String get categoryShowOnCalendar => 'In de kalender tonen';

  @override
  String get categoryHideOnCalendar => 'In de kalender verbergen';

  @override
  String get categoryEditColor => 'Categoriekleur wijzigen';

  @override
  String get categoryThemePalette => 'Themapalet';

  @override
  String get categoryCustomColor => 'Aangepast';

  @override
  String get colorHexInvalid =>
      'Voer een hexadecimale kleurcode van zes tekens in.';

  @override
  String categoryColorSlot(int number) {
    return 'Themakleur $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Updates in de winkel kunnen later beschikbaar zijn. Raadpleeg de winkelpagina voor de beschikbaarheid.';

  @override
  String get storePrereleaseNotice =>
      'Het ontvangen van meldingen over voorlopige versies meldt je niet aan voor een testprogramma in de winkel.';

  @override
  String get updateFoundTitle => 'Nieuwe versie beschikbaar';

  @override
  String get updateNoNotes => 'Er zijn geen releaseopmerkingen opgegeven.';

  @override
  String get updateLater => 'Later';

  @override
  String get updateRetry => 'Opnieuw proberen';

  @override
  String get updatePrerelease => 'Voorlopige versie';

  @override
  String get updateNetworkFailure =>
      'Kan niet op updates controleren. Controleer je verbinding en probeer het opnieuw.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Geen nieuwere versie gevonden (huidig: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Back-up wordt hersteld…';

  @override
  String get backupRestoreInProgressMessage =>
      'Gegevens en instellingen kunnen na het herstellen worden gewijzigd. Je kunt ze nog wel bekijken.';
}
