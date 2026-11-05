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
  String get schoolImportResultEditorTitle => 'JSON bewerken';

  @override
  String get schoolImportParsePageTitle => 'Rooster analyseren';

  @override
  String get schoolImportParsePageParsing => 'Analyseren…';

  @override
  String get schoolImportParsePageFailed => 'Analyse mislukt';

  @override
  String get schoolImportParseErrorMessage =>
      'Het lesrooster kon niet worden verwerkt. Controleer de inhoud, de parserinstellingen en de netwerkverbinding en probeer het opnieuw.';

  @override
  String get schoolImportParsePageContinue => 'Doorgaan';

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
      'Maak een lesrooster of kies een importmethode.';

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
  String get customFieldsInvalidJson =>
      'Voer een geldig JSON-object in of maak het veld leeg.';

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
  String get settingsSectionAppearance => 'Weergave';

  @override
  String get settingsSectionWorkspace => 'Werkruimte';

  @override
  String get settingsSectionAbout => 'Over Sked';

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
  String get enableWeekSwipeNavigation => 'Vegen om van week te wisselen';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Veeg naar links of rechts om naar een andere week te gaan. Sleep bij vaste breedtes eerst voorbij de rand.';

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
  String get appBackupTitle => 'App backup and restore';

  @override
  String get appBackupSheetSubtitle =>
      'Choose which objects to back up or restore. Unselected data is kept, and API keys are never exported.';

  @override
  String get restoreBackupFileTitle => 'Restore from backup file';

  @override
  String get restoreBackupFileSubtitle =>
      'Choose a ZIP or legacy JSON backup, then select objects and confirm the restore.';

  @override
  String get restoreBackupTextTitle => 'Back-up-JSON plakken';

  @override
  String get restoreBackupTextSubtitle =>
      'Paste a legacy JSON backup, then select the objects to restore.';

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
      'Show legacy JSON for business data, app preferences and school sites. Chats, files and Agent configuration are excluded.';

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
  String get includePrereleaseUpdates => 'Voorlopige updates ontvangen';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Neem Alpha-, Beta- en RC-versies op, die instabiel kunnen zijn. Uitgeschakeld worden alleen stabiele versies aangeboden.';

  @override
  String get currentVersionLabel => 'Huidige versie';

  @override
  String get newVersionAvailable => 'Update beschikbaar';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get ignoreThisVersion => 'Deze versie negeren';

  @override
  String get openUpdatesFailed => 'De updatelink kan niet worden geopend';

  @override
  String get updateCheckFailedTitle => 'Controleren op updates mislukt';

  @override
  String get githubRepository => 'GitHub-repository';

  @override
  String get googlePlayStoreDesc => 'Sked bekijken op Google Play';

  @override
  String get openGooglePlayFailed => 'Google Play kan niet worden geopend';

  @override
  String get microsoftStoreDesc => 'Sked bekijken in de Microsoft Store';

  @override
  String get openMicrosoftStoreFailed =>
      'De Microsoft Store kan niet worden geopend';

  @override
  String get starSkedOnGithub => 'Geef Sked een ster op GitHub!';

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
  String get importTimetableText => 'Import timetable from JSON text';

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
  String get exportTimetableText => 'Export timetable as JSON text';

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
  String get copyFailed => 'Could not copy. Please try again.';

  @override
  String get share => 'Delen';

  @override
  String get selectTimetablesToExport => 'Kies roosters om te exporteren';

  @override
  String get selectTimetablesToImport => 'Kies roosters om te importeren';

  @override
  String get studentDayNextCourse => 'Next course';

  @override
  String get studentDayNoMoreCourses =>
      'No later courses in this timetable\'s semester.';

  @override
  String get studentDayEmpty => 'Geen lessen op deze dag';

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
      'How local data, import and export, optional network requests and external links are handled.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Geaccepteerde versie: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked is een roosterhulpmiddel dat lokale opslag vooropstelt. Lesroosters, algemene agenda’s, sets met lestijden en instellingen voor schoolwebsites worden alleen op je apparaat of in je browser opgeslagen en nooit automatisch geüpload. De app verwerkt gegevens alleen wanneer je uitdrukkelijk acties start, zoals importeren, roostertekst / HTML analyseren, schoolwebpagina’s importeren, delen of externe links openen. Het volledige privacybeleid is online beschikbaar.';

  @override
  String get privacyGateTitle =>
      'Ga akkoord met het privacybeleid voordat je de app gebruikt';

  @override
  String get privacyGateSummaryStorage =>
      'Lesroosters, algemene agenda’s, sets met lestijden en instellingen voor schoolwebsites worden alleen lokaal opgeslagen en niet automatisch naar een server van de ontwikkelaar geüpload.';

  @override
  String get privacyGateSummaryImportExport =>
      'Imports, exports, backups, and sharing happen when you request them. Backups can include chats and files you select; API keys are excluded. When you use Agent, your messages, attachments, and task-related app data returned by tools are sent to your configured API service.';

  @override
  String get privacyGateSummaryUpdates =>
      'Als een latere versie de verwerking van gegevens verandert, kan de app je vragen het aangepaste privacybeleid opnieuw te bekijken.';

  @override
  String get schoolWebImportEntry => 'Importeren van een schoolwebsite';

  @override
  String get schoolWebImportEntryDesc =>
      'Importeer de huidige roosterpagina van de schoolwebsite.';

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
  String get schoolHtmlImportEntry => 'Parse timetable from text / HTML';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Paste plain timetable text, page text, or HTML source, then import it through your custom parser endpoint.';

  @override
  String get schoolHtmlImportPageTitle => 'Parse timetable text / HTML';

  @override
  String get schoolHtmlImportHtmlLabel => 'Text / HTML content';

  @override
  String get schoolHtmlImportHtmlHint =>
      'For example, \"Monday periods 3-4 Chinese\", or paste timetable page text or HTML source.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Any content containing timetable information can be parsed and imported; plain text and HTML are both supported.';

  @override
  String get schoolHtmlImportCompress => 'Inhoud voorbereiden';

  @override
  String get schoolHtmlImportCompressed => 'Inhoud voorbereid';

  @override
  String get schoolHtmlImportSubmit => 'Analyseren en importeren';

  @override
  String get schoolImportContentTruncated =>
      'Deze pagina heeft de veilige importlimiet bereikt. Alleen het vastgelegde gedeelte wordt verzonden voor analyse.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Het analyseren kan even duren. Even geduld.';

  @override
  String get schoolHtmlImportEmpty =>
      'Paste timetable text or HTML content first.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Terug naar de webpagina';

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
  String get schoolWebImportUnsupportedPlatform =>
      'Dit platform ondersteunt ingebouwd inloggen op websites nog niet. Gebruik een platform met WebView-ondersteuning.';

  @override
  String get schoolWebImportNoSchools => 'Geen scholen beschikbaar.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'De schoolconfiguratie kon niet worden geladen. Probeer het opnieuw.';

  @override
  String get schoolWebImportImportCurrentPage => 'Huidige pagina importeren';

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
  String get schoolImportWithoutApiTitle => 'Add a timetable without an API';

  @override
  String get schoolImportManualHint =>
      'To add courses manually, return to the timetable workspace, create or select a timetable, then choose Add course.';

  @override
  String get schoolImportFileAction => 'Import timetable JSON';

  @override
  String get schoolImportAiHint =>
      'To parse pasted content or a school webpage, connect an OpenAI-compatible API. The content you submit will be sent to that endpoint.';

  @override
  String get schoolImportConfigureAction => 'Configure parsing API';

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
      'Het rooster dat je wilt vervangen, is niet beschikbaar. Selecteer opnieuw een rooster.';

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
  String get firstLaunchTitle => 'Kies welke werkruimtes je wilt inschakelen';

  @override
  String get firstLaunchSubtitle =>
      'Gebruik het lesrooster, de agenda of beide. Je kunt dit later wijzigen in de instellingen.';

  @override
  String get firstLaunchStudentDesc =>
      'Beheer roosters, vakken, weken, lestijden en import.';

  @override
  String get firstLaunchGeneralDesc =>
      'Beheer categorieën, evenementen, herinneringen en JSON / ICS-gegevens.';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Door een werkruimte te kiezen, bevestig je dat je het ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Privacybeleid';

  @override
  String get firstLaunchPrivacyConsentAfter =>
      ' hebt gelezen en ermee akkoord gaat.';

  @override
  String get switchMode => 'Modus wisselen';

  @override
  String get switchToStudentTimetable => 'Naar het lesrooster';

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
  String get reminder => 'Herinnering';

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
  String get generalFitWeekColumnsToWidth =>
      'Weekweergave aan scherm aanpassen';

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
  String get icsReminderExportTitle => 'ICS-export bevat geen herinneringen';

  @override
  String get icsReminderExportMessage =>
      'Herinneringen worden niet opgenomen in de geëxporteerde ICS. Kies JSON om de herinneringsinstellingen te behouden.';

  @override
  String get icsReminderExportJsonAction => 'JSON exporteren';

  @override
  String get icsReminderExportContinueAction => 'Doorgaan met ICS';

  @override
  String get icsReminderImportNotice =>
      'Herinneringen staan uit voor gebeurtenissen die uit ICS worden geïmporteerd. Gebruik JSON om de herinneringsinstellingen te herstellen.';

  @override
  String get icsReminderReplaceTitle =>
      'Gebeurtenissen en herinneringen vervangen?';

  @override
  String icsReminderReplaceMessage(String calendar) {
    return 'Als je ‘$calendar’ vervangt door ICS-gebeurtenissen, worden de gebeurtenissen in deze categorie overschreven en hun herinneringen uitgezet. Annuleer om eerst een JSON-back-up te exporteren, of ga terug en voeg een nieuwe categorie toe.';
  }

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
    return 'Niet-ondersteunde ICS-velden zijn genegeerd: $fields';
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
  String developerNotificationPlanError(Object message) {
    return 'Laatste fout: $message';
  }

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
  String get developerNotificationNextRenewal =>
      'Volgende poging tot opnieuw inplannen';

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
  String get notificationSettingsSection => 'Herinneringen en meldingen';

  @override
  String get notificationCoverage => 'Dekking van herinneringen';

  @override
  String get notificationCoverageBlocked =>
      'Reminders are blocked and will not fire. Check notification settings.';

  @override
  String get notificationCoverageFailed =>
      'Reminders could not be synced. Open notification settings and try again.';

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
  String get notificationBatteryOptimizationWarning =>
      'Battery optimization or vendor background restrictions may delay reminders. You can adjust these in system settings.';

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
  String get notificationLockScreenTitles => 'Titels in meldingen tonen';

  @override
  String get notificationLockScreenTitlesHint =>
      'Geldt ook voor het vergrendelscherm. Als dit uitstaat, bevatten meldingen alleen het type en de tijd.';

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
  String get settingsDataPrivacy => 'Gegevens en privacy';

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
      'Discuss and work in the current workspace. This preview only demonstrates the layout; AI is not connected.';

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
  String get colorPickerHue => 'Tint';

  @override
  String get colorPickerSaturation => 'Verzadiging';

  @override
  String get colorPickerValue => 'Helderheid';

  @override
  String get colorPickerHex => 'Hexkleur';

  @override
  String get colorPickerSpectrum => 'Kleurenspectrum';

  @override
  String get colorPickerSpectrumKeyboardHint =>
      'Gebruik de pijlen links en rechts om de verzadiging aan te passen, en omhoog en omlaag voor de helderheid.';

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

  @override
  String get managePeriodTimeSets => 'Lestijdenschema\'s beheren';

  @override
  String periodTimeSetUsageSummary(int periodCount, int timetableCount) {
    return 'Lesuren: $periodCount · Gekoppelde roosters: $timetableCount';
  }

  @override
  String chooseTimetableImportMethod(String name) {
    return 'Importeer als nieuw rooster of vervang alle roostergegevens en lessen in ‘$name’.';
  }

  @override
  String get selectAtLeastOneWeek => 'Selecteer ten minste één week.';

  @override
  String get notificationRemindHiddenGeneralCalendars =>
      'Herinneringen voor verborgen categorieën behouden';

  @override
  String get notificationRemindHiddenGeneralCalendarsHint =>
      'Geldt voor herinneringen in de app en systeemmeldingen. Systeemmeldingen moeten ook ingeschakeld zijn.';

  @override
  String get generalReminderFollowDefault => 'Standaard gebruiken';

  @override
  String get generalReminderCustom => 'Aangepaste herinneringen';

  @override
  String get eventEditScopeTitle => 'Terugkerende afspraak bewerken';

  @override
  String get eventEditThisOccurrence => 'Alleen deze afspraak';

  @override
  String get eventEditThisAndFollowing => 'Deze en volgende afspraken';

  @override
  String get eventEditEntireSeries => 'Hele reeks';

  @override
  String get eventEditEntireSeriesHint =>
      'Wijzigingen gelden voor de hele reeks, inclusief afspraken in het verleden.';

  @override
  String get eventEditConflict =>
      'Deze afspraak is gewijzigd. Je concept blijft bewaard; open de afspraak opnieuw om de nieuwste versie te bekijken.';

  @override
  String eventSavedToHiddenCalendar(String name) {
    return 'Opgeslagen in de verborgen categorie ‘$name’.';
  }

  @override
  String get viewEvent => 'Afspraak bekijken';

  @override
  String get schoolSitesNameRequired => 'Voer een schoolnaam in.';

  @override
  String get schoolSitesLoginUrlRequired => 'Voer een inlog-URL in.';

  @override
  String get languageNoResults => 'Geen overeenkomende talen';

  @override
  String get themeGeneralMonthTextColors => 'Tekst in maandweergave';

  @override
  String get themeGeneralFestivalTextColor => 'Feesten en feestdagen';

  @override
  String get themeGeneralSolarTermTextColor => 'Zonneperioden';

  @override
  String get themeGeneralLunarTextColor => 'Maandata';

  @override
  String get courseTextLowContrastHint =>
      'Deze tekstkleur is mogelijk moeilijk leesbaar op sommige cursuskaarten (contrast lager dan 4.5:1). Je kunt de kleur behouden of een andere kiezen.';

  @override
  String get shortenSemesterTitle => 'Semester inkorten?';

  @override
  String shortenSemesterMessage(int weeks, int count) {
    return 'Het semester eindigt in week $weeks. Cursussen met latere lessen: $count. Cursussen en geselecteerde weken blijven behouden. Herstel het aantal weken om ze weer te zien.';
  }

  @override
  String get defaultGeneralCalendarName => 'Mijn agenda';

  @override
  String get icsImportReportTitle => 'Importrapport';

  @override
  String get icsImportReportAction => 'Rapport bekijken';

  @override
  String get icsExportFailureTitle => 'Exporteren als ICS niet mogelijk';

  @override
  String get icsCopyDiagnosticsAction => 'Details kopiëren';

  @override
  String get icsUnsupportedTimeZoneMessage =>
      'Deze ICS bevat benoemde tijdzones die Sked niet veilig kan interpreteren. Er is niets geïmporteerd. Exporteer UTC of lokale tijden zonder tijdzone uit de bronagenda en probeer het opnieuw.';

  @override
  String get icsExportMonthlyAnchorMismatchMessage =>
      'Deze maandelijkse afspraak kan niet nauwkeurig worden weergegeven in ICS. Exporteer JSON om de datums te behouden.';

  @override
  String get icsExportEmptyRecurrenceMessage =>
      'Deze herhalende afspraak heeft geen geldige voorkomens voor ICS-export. Exporteer JSON om de registratie te behouden.';

  @override
  String get icsImportedCalendarName => 'Geïmporteerde agenda';

  @override
  String get icsUntitledEventName => 'Afspraak zonder titel';

  @override
  String notificationWindowsCoverageLimit(int days, int capacity) {
    return 'Windows plant alleen herinneringen voor de komende $days dagen, maximaal $capacity tegelijk. Open de app regelmatig opnieuw om het plan bij te werken.';
  }

  @override
  String notificationWindowsCoverageSummary(int count, String date) {
    return 'Geplande herinneringen: $count. De laatste controle loopt tot $date.';
  }

  @override
  String get notificationWindowsCoverageCapacityLimited =>
      'De herinneringslimiet is bereikt. Sommige herinneringen zijn nog niet gepland. Open de app opnieuw nadat komende herinneringen zijn afgegaan om het plan bij te werken.';

  @override
  String get courseInactiveThisWeek => 'Deze week niet ingepland';

  @override
  String get courseInactiveBadge => 'Off week';

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
  String get notificationSnoozeAction => '10 minuten uitstellen';

  @override
  String get notificationHandledAction => 'Als afgehandeld markeren';

  @override
  String get developerTestNotificationTitle => 'Sked-testmelding';

  @override
  String get developerTestNotificationCourseBody =>
      'Het kanaal voor cursusherinneringen werkt.';

  @override
  String get developerTestNotificationScheduleBody =>
      'Het kanaal voor afspraakherinneringen werkt.';

  @override
  String get eventRecurrenceExceptionsChangeTitle => 'Change repeat pattern?';

  @override
  String get eventRecurrenceExceptionsChangeMessage =>
      'Previously skipped dates stay skipped only if the new repeat pattern still has an occurrence on that date. Other skip records will be removed. Turning repeats off removes all skip records. Events edited separately stay unchanged.';

  @override
  String get noPendingReminders => 'No pending reminders.';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentNewConversation => 'New conversation';

  @override
  String get agentConversations => 'Conversations';

  @override
  String get agentRenameConversation => 'Rename conversation';

  @override
  String get agentDeleteConversation => 'Delete conversation?';

  @override
  String get agentDeleteConversationMessage =>
      'This stops its active run and deletes its messages, source material and draft. Changes already made to your schedules remain.';

  @override
  String get agentConversationActions => 'Conversation actions';

  @override
  String get agentEmptyHistory => 'No conversations yet.';

  @override
  String get agentEmptyConversation =>
      'Describe what you want to view or change in Sked.';

  @override
  String get agentMessageHint => 'Message Agent';

  @override
  String get agentSend => 'Send';

  @override
  String get agentStop => 'Stop';

  @override
  String get agentRunning => 'Working…';

  @override
  String get agentStopped => 'Stopped. Completed changes remain saved.';

  @override
  String get agentRunFailed => 'This run could not finish.';

  @override
  String get agentOperationFailed =>
      'Could not save or complete this action. Your input is kept here.';

  @override
  String get agentInitializing => 'Loading Agent…';

  @override
  String get agentInitializationFailed => 'Agent could not finish loading.';

  @override
  String get agentInitializationApplicationStorage =>
      'Application storage is not ready. Return to the workspace and resolve its storage or recovery notice before retrying.';

  @override
  String get agentInitializationConversationStorage =>
      'Saved chats could not be loaded. Existing records are preserved. Check storage access or archive format, then retry.';

  @override
  String get agentInitializationConnectionStorage =>
      'The saved connection could not be initialized. Open Agent settings to review it, then retry.';

  @override
  String get agentRetry => 'Retry';

  @override
  String get agentDisabled => 'Agent is disabled in Feature management.';

  @override
  String get agentMaintenance =>
      'Data maintenance is in progress. Wait before starting another action.';

  @override
  String get agentConfigureFirst =>
      'Configure the model connection before sending a message.';

  @override
  String get agentModePlan => 'Plan';

  @override
  String get agentModeAsk => 'Ask';

  @override
  String get agentModeFull => 'Full';

  @override
  String get agentModePlanDescription =>
      'View data and propose changes without applying them.';

  @override
  String get agentModeAskDescription =>
      'Ask for approval before applying changes.';

  @override
  String get agentModeFullDescription =>
      'Apply changes without asking each time.';

  @override
  String get agentAssistant => 'Agent';

  @override
  String get agentYou => 'You';

  @override
  String get agentNotice => 'Notice';

  @override
  String get agentToolResponse => 'Tool response';

  @override
  String get agentToolArguments => 'Tool arguments';

  @override
  String get agentSourceMaterial => 'Source material';

  @override
  String get agentSourceTruncated =>
      'This source was shortened before it was attached.';

  @override
  String get agentApprovalRequired => 'Review the proposed changes';

  @override
  String get agentPlanDetails => 'Change details';

  @override
  String get agentApprove => 'Approve these changes';

  @override
  String get agentReject => 'Reject';

  @override
  String get agentApiDataNotice =>
      'Agent sends your messages, attachments, and task-related app data returned by tools to the API service you configure.';

  @override
  String get agentModelSettings => 'Agent model settings';

  @override
  String get agentEndpoint => 'API endpoint';

  @override
  String get agentModel => 'Model';

  @override
  String get agentProtocol => 'API protocol';

  @override
  String get agentApiKey => 'API key';

  @override
  String get agentKeyHint => 'Leave blank to keep the saved key.';

  @override
  String get agentShowKey => 'Show key';

  @override
  String get agentHideKey => 'Hide key';

  @override
  String get agentClearKey => 'Remove the saved key';

  @override
  String get agentInvalidEndpoint =>
      'Enter a valid HTTP or HTTPS endpoint without credentials or a fragment.';

  @override
  String get agentRequiredField => 'Enter a value.';

  @override
  String get agentSaveFailed =>
      'Could not save the connection. Your input is kept for retry.';

  @override
  String get agentSaving => 'Saving…';

  @override
  String get schoolWebAgentReviewTitle => 'Review school page';

  @override
  String get schoolWebAgentReviewHint =>
      'Review the prepared page content. Agent will use it as source material in a new conversation.';

  @override
  String get schoolWebAgentHandoff => 'Continue with Agent';

  @override
  String get agentChangesSaved => 'Changes saved';

  @override
  String agentNotificationEffect(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'pending': 'Reminder scheduling is pending.',
      'applied': 'The reminder schedule was updated.',
      'superseded': 'A newer change replaced this reminder plan.',
      'failed': 'Reminder scheduling failed. Your changes are saved.',
      'blocked':
          'Device permissions or notification settings blocked scheduling.',
      'unsupported': 'Reminder scheduling is unavailable on this platform.',
      'notRequired': 'This change does not require rescheduling reminders.',
      'other': 'The reminder scheduling result needs checking.',
    });
    return '$_temp0';
  }

  @override
  String get agentActionApplied => 'Action completed';

  @override
  String get agentActionUncertain => 'Result needs checking';

  @override
  String get agentPlanReady => 'Changes prepared';

  @override
  String get agentActionFailed => 'Action not completed';

  @override
  String agentChangeCount(int count) {
    return '$count changes';
  }

  @override
  String get agentChangeCreated => 'Added';

  @override
  String get agentChangeDeleted => 'Deleted';

  @override
  String get agentChangeUpdated => 'Updated';

  @override
  String get agentChangeArchived => 'Archived';

  @override
  String get agentChangeRestored => 'Restored';

  @override
  String get agentLayoutWidth => 'Panel width';

  @override
  String get agentLayoutHeight => 'Panel height';

  @override
  String get agentLayoutDockedWidth => 'Side-by-side panel width';

  @override
  String get agentLayoutResources => 'Workspace resources';

  @override
  String get agentLayoutCourseDetails => 'Course details';

  @override
  String get agentLayoutEventDetails => 'Event details';

  @override
  String get agentViewObject => 'View item';

  @override
  String get agentMoreChanges =>
      'More changes are included in the saved operation record.';

  @override
  String get agentUndo => 'Undo these changes';

  @override
  String get agentValueBefore => 'Before';

  @override
  String get agentValueAfter => 'After';

  @override
  String get agentShowMoreChanges => 'Show more changes';

  @override
  String get agentConnectionChanged =>
      'The model connection has changed. Start a new conversation before sending content to the new endpoint.';

  @override
  String get agentLimitsReached =>
      'This run reached its limit. Try a smaller task or continue in another run.';

  @override
  String get agentSensitiveContent =>
      'The message contains an API key. Remove the key before sending.';

  @override
  String get agentRequestFailed =>
      'The model request failed. Check the connection and selected model, then retry.';

  @override
  String get agentQueueFollowUp => 'Queue next message';

  @override
  String get agentSteer => 'Update current request';

  @override
  String get agentContinue => 'Continue';

  @override
  String agentQueuedMessages(int count) {
    return '$count queued messages';
  }

  @override
  String get agentRunPreferences => 'Run preferences';

  @override
  String get agentSystemInstructions => 'Instructions for all conversations';

  @override
  String get agentMaxModelRounds => 'Maximum model requests per run';

  @override
  String get agentMaxToolCalls => 'Maximum tool calls per run';

  @override
  String get agentMaxTotalTokens => 'Maximum reported tokens per run';

  @override
  String get agentHistoryRetentionDays =>
      'History retention (days; 0 keeps history)';

  @override
  String get agentPreferenceLimitHint =>
      'Keep forever, or choose 7–3650 days. Only finished conversations without drafts or queued input are removed.';

  @override
  String get agentPreferencesSaved => 'Preferences saved';

  @override
  String get agentInvalidPreference =>
      'Enter a value within the displayed range.';

  @override
  String get agentBackupConnectionPreserved =>
      'The local Agent connection, permissions and credentials are preserved. This backup will not change the model connection.';

  @override
  String get agentArchiveConversation => 'Archive conversation';

  @override
  String get agentArchivedConversations => 'Archived conversations';

  @override
  String get agentRestoreConversation => 'Restore conversation';

  @override
  String get agentExportConversation => 'Export conversation';

  @override
  String agentSavedConnectionHint(String endpoint) {
    return 'Diagnostics use the saved connection: $endpoint. Unsaved edits are not sent.';
  }

  @override
  String get agentTestConnection => 'Test saved connection';

  @override
  String get agentLoadModels => 'Get models';

  @override
  String get agentConnectionOk => 'Connection succeeded';

  @override
  String get agentToolsObserved => 'Valid tool call received';

  @override
  String get agentToolsUnverified =>
      'Connected, but tool calling was not verified';

  @override
  String get agentModelsPartial => 'The service returned a partial model list.';

  @override
  String get agentChooseModel => 'Choose a model';

  @override
  String get agentRecoveryRequired =>
      'Check the previous operation result first. Only reading is currently allowed.';

  @override
  String get agentAttachFile => 'Attach a text file';

  @override
  String get agentRemoveAttachment => 'Remove attachment';

  @override
  String get agentAttachmentTooLarge =>
      'This attachment exceeds the 512 KiB limit.';

  @override
  String get agentAttachmentFailed =>
      'Could not attach the file. Your conversation is unchanged.';

  @override
  String get agentHttpTransportWarning =>
      'This connection uses HTTP. Testing, getting models or sending a request transmits the API key and request content without transport encryption.';

  @override
  String get agentHttpTransportApproval =>
      'Allow HTTP requests to this connection?';

  @override
  String get agentHttpTransportScope =>
      'This permission can be reused for the same saved connection until the app closes. It does not approve changes to your data.';

  @override
  String get agentModelSelection => 'Model';

  @override
  String get agentThinkingEffort => 'Thinking effort';

  @override
  String get agentEffortNone => 'None';

  @override
  String get agentEffortMinimal => 'Minimal';

  @override
  String get agentEffortLow => 'Low';

  @override
  String get agentEffortMedium => 'Medium';

  @override
  String get agentEffortHigh => 'High';

  @override
  String get agentEffortXhigh => 'Extra high';

  @override
  String get agentEffortMax => 'Maximum';

  @override
  String get agentModelNextRunHint =>
      'Changes apply to the next request. The current request keeps its model and thinking effort.';

  @override
  String get agentModelSelectionRequired =>
      'This request\'s model or thinking effort is no longer enabled. Choose another option, then continue.';

  @override
  String get agentEnabledModels => 'Available models';

  @override
  String get agentAddModel => 'Add model';

  @override
  String get agentModelSearch => 'Search model IDs';

  @override
  String get agentDefaultModel => 'Default model';

  @override
  String get agentDefaultEffort => 'Default thinking effort';

  @override
  String get agentAllowedEfforts => 'Available thinking efforts';

  @override
  String get agentNoModelsSelected => 'Select or add at least one model.';

  @override
  String get agentModelCapabilityHint =>
      'A model list does not describe supported thinking levels. Select the levels your service supports and choose an explicit default.';

  @override
  String get agentModelEffortsRequired =>
      'Select at least one thinking effort and choose its default for every enabled model.';

  @override
  String get agentRemoveModel => 'Remove model';

  @override
  String get agentManualModelId => 'Model ID';

  @override
  String get agentSettingsTitle => 'Agent settings';

  @override
  String get agentConnectionAndModels => 'Connection and models';

  @override
  String get agentConnectionSettings => 'Connection settings';

  @override
  String get agentSettingsChanged =>
      'Settings changed elsewhere. Reopen this page to load the latest values.';

  @override
  String get agentSettingsSaveFailed =>
      'Couldn\'t save settings. Your changes are still here.';

  @override
  String get agentSettingsSummary => 'Manage models and Agent preferences';

  @override
  String get agentOpenWorkspace => 'Open full chat';

  @override
  String get agentSearchConversations => 'Search conversations';

  @override
  String get agentHideConversations => 'Hide conversations';

  @override
  String get agentShowConversations => 'Show conversations';

  @override
  String get agentJumpToLatest => 'Latest messages';

  @override
  String get agentCopyMessage => 'Copy message';

  @override
  String get agentCopyCode => 'Copy code';

  @override
  String get agentCopied => 'Copied';

  @override
  String get agentCopyFailed => 'Could not copy. Try again.';

  @override
  String get agentChatWelcome => 'What can I help with?';

  @override
  String get agentActivityDetails => 'Activity details';

  @override
  String agentActivitySummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activities',
      one: '1 activity',
    );
    return '$_temp0';
  }

  @override
  String get agentActivityCompleted => 'Completed';

  @override
  String get agentActivityFailed => 'Failed';

  @override
  String get agentActivityUncertain => 'Needs review';

  @override
  String get agentActivityNotStarted => 'Not started';

  @override
  String get agentActivityEmptyOutput => 'No content';

  @override
  String get agentCopyActivity => 'Copy activity details';

  @override
  String get agentActivityRead => 'Read information';

  @override
  String get agentActivityCapabilities => 'Check available features';

  @override
  String get agentActivityPrepare => 'Prepare changes';

  @override
  String get agentActivityCommit => 'Save changes';

  @override
  String get agentActivityNotifications => 'Check reminders';

  @override
  String get agentActivityKnowledge => 'Work with knowledge';

  @override
  String get agentActivitySettings => 'Work with settings';

  @override
  String get agentActivitySystem => 'Use system features';

  @override
  String get agentActivityTool => 'Use a tool';

  @override
  String get agentConversationSearchEmpty => 'No matching conversations';

  @override
  String get agentPermissionMode => 'Permission mode';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentMemories => 'Memory';

  @override
  String get agentKnowledgeAdd => 'Add';

  @override
  String get agentKnowledgeBody => 'Content';

  @override
  String get agentKnowledgeBuiltin => 'Built-in';

  @override
  String get agentKnowledgeConflict =>
      'This item changed. Reopen it before saving.';

  @override
  String get agentKnowledgeCustom => 'Custom';

  @override
  String get agentKnowledgeDelete => 'Delete';

  @override
  String get agentKnowledgeDeleteConfirm =>
      'Delete this item? Recent local history may retain a copy for undo.';

  @override
  String get agentKnowledgeEdit => 'Edit';

  @override
  String get agentKnowledgeEmpty => 'Nothing saved yet';

  @override
  String get agentKnowledgeEnabled => 'Enabled';

  @override
  String get agentKnowledgeHelp =>
      'Skills guide how the Agent handles tasks. You and the Agent share them. Changes apply to future runs.';

  @override
  String get agentKnowledgeInvalid =>
      'Check the content, tool names and size limits.';

  @override
  String get agentKnowledgeMemoryHelp =>
      'Shared notes and preferences. The Agent may update them during a conversation using its current permissions. Check current data before relying on older details.';

  @override
  String get agentKnowledgeModified => 'Customized built-in';

  @override
  String get agentKnowledgeOriginalChanged =>
      'The built-in version changed. Your edits are kept until you restore the original.';

  @override
  String get agentKnowledgeReload => 'Reload';

  @override
  String get agentKnowledgeRestoreOriginal => 'Restore original';

  @override
  String get agentKnowledgeSaved => 'Saved';

  @override
  String get agentKnowledgeSearch => 'Search';

  @override
  String get agentKnowledgeSource => 'Source or context';

  @override
  String get agentKnowledgeStaleReference =>
      'Referenced data may have changed. Check current data before using this note.';

  @override
  String get agentKnowledgeStorageFailed =>
      'The saved state could not be confirmed. Reload to check it before making more changes.';

  @override
  String get agentKnowledgeSummary => 'Summary';

  @override
  String get agentKnowledgeTitle => 'Title';

  @override
  String get agentKnowledgeUnavailable => 'Unavailable';

  @override
  String get agentKnowledgeUndo => 'Undo';

  @override
  String get agentSkillAdvanced => 'Skill options';

  @override
  String get agentSkillOptionalTools => 'Optional tools, one name per line';

  @override
  String get agentSkillRequiredTools => 'Required tools, one name per line';

  @override
  String get agentSkillTriggers => 'When to use this skill, one hint per line';

  @override
  String get agentComposerActions => 'Message actions';

  @override
  String get agentMakeDefaultModel => 'Use as default model';

  @override
  String get agentModelIdExists => 'This model has already been added.';

  @override
  String get agentAttachAnyFile => 'Attach a file';

  @override
  String get agentFileLocal => 'Saved on this device';

  @override
  String get agentFileSaving => 'Saving file…';

  @override
  String get agentFilePreparing => 'Preparing to send…';

  @override
  String get agentFileSending => 'Sending file…';

  @override
  String get agentFileAccepted => 'Accepted by the service';

  @override
  String get agentFileFailed => 'File was not accepted';

  @override
  String get agentFileCancelled => 'File transfer stopped';

  @override
  String get agentFileUnknown => 'Service acceptance is unknown';

  @override
  String get agentFileTooLarge => 'A file can be up to 32 MB.';

  @override
  String get agentFileChanged =>
      'The file changed while it was being read. Select it again.';

  @override
  String get agentFileMissing =>
      'This file is no longer available on this device. Select it again to use it.';

  @override
  String get agentFileCorrupt =>
      'The saved file could not be verified. Select the original file again.';

  @override
  String get agentFileUnavailable =>
      'File storage is unavailable. Retry after restoring access.';

  @override
  String get agentFileUnsupported =>
      'This API protocol cannot send this file type. The local file is kept.';

  @override
  String get agentFileConflict =>
      'The conversation changed while the file was being added, or the attachment limit was reached.';

  @override
  String get agentFilePreview => 'Preview file';

  @override
  String get agentFileUseAgain => 'Use in the next message';

  @override
  String get agentFileNoPreview =>
      'Preview is not available for this file type. The saved file can still be sent if the API supports it.';

  @override
  String get agentFilePreviewFailed => 'This image could not be displayed.';

  @override
  String get agentFileReceivedHint =>
      'Acceptance confirms the service received the request; it does not confirm that the model read every file.';

  @override
  String get selectiveBackupAdd => 'Add';

  @override
  String get selectiveBackupAgentConnection => 'Agent connection and models';

  @override
  String get selectiveBackupAgentPreferences => 'Agent preferences';

  @override
  String get selectiveBackupApplicationSettings => 'Application settings';

  @override
  String get selectiveBackupCalendars => 'Calendar categories';

  @override
  String get selectiveBackupCalendarSettings => 'Calendar settings';

  @override
  String get selectiveBackupCancelled =>
      'Restore cancelled. Your selection is kept.';

  @override
  String get selectiveBackupClearSelection => 'Clear selection';

  @override
  String get selectiveBackupConfirmBody =>
      'Selected objects with the same ID will be replaced. New objects will be added, and unselected objects will be kept.';

  @override
  String get selectiveBackupConfirmTitle => 'Restore selected data?';

  @override
  String get selectiveBackupConflict =>
      'Some selected objects conflict with data used elsewhere. Include the related objects or cancel this restore.';

  @override
  String get selectiveBackupConversations => 'Conversations';

  @override
  String selectiveBackupCopiedDependencies(int count) {
    return 'Copy and rebind $count dependencies';
  }

  @override
  String get selectiveBackupCurrentData => 'Current data';

  @override
  String get selectiveBackupDependencies =>
      'Required dependencies are included automatically. Conflicting dependencies are copied and linked only to the selected objects.';

  @override
  String get selectiveBackupDescription =>
      'Choose individual objects and settings groups to back up or restore. Conversation files can be selected separately.';

  @override
  String get selectiveBackupExclusions =>
      'API keys, cookies, system permissions and execution approvals are excluded. Restored chats contain history only and do not resume old actions.';

  @override
  String get selectiveBackupExportSelection => 'Choose data to back up';

  @override
  String get selectiveBackupFileMissing =>
      'This backup contains a reference only; file bytes are not included.';

  @override
  String get selectiveBackupFiles => 'Conversation files';

  @override
  String get selectiveBackupFilesDescription =>
      'Select file contents separately. Unchecked files retain only history references; their contents will be unavailable after restore.';

  @override
  String selectiveBackupFileSize(int bytes) {
    return '$bytes bytes';
  }

  @override
  String get selectiveBackupInvalid => 'This file is not a valid Sked backup.';

  @override
  String get selectiveBackupLimit =>
      'This backup exceeds the supported size or object limit.';

  @override
  String get selectiveBackupMemories => 'Memory';

  @override
  String get selectiveBackupNewerVersion =>
      'This backup uses a newer format. Update Sked before restoring it.';

  @override
  String get selectiveBackupNotificationSettings => 'Notification settings';

  @override
  String get selectiveBackupOpenFile => 'Open backup';

  @override
  String get selectiveBackupPeriodTimes => 'Period time sets';

  @override
  String get selectiveBackupRecoveryPending =>
      'A restore is unfinished. Continue the same restore before changing data.';

  @override
  String get selectiveBackupReplace => 'Replace';

  @override
  String get selectiveBackupRestore => 'Restore';

  @override
  String selectiveBackupRestoreCounts(int added, int replaced) {
    return 'Add $added; replace $replaced';
  }

  @override
  String get selectiveBackupRestored => 'Selected data restored';

  @override
  String get selectiveBackupRestoreSelection => 'Choose data to restore';

  @override
  String get selectiveBackupResume => 'Continue restore';

  @override
  String get selectiveBackupReviewRestore => 'Review restore';

  @override
  String get selectiveBackupSave => 'Save backup';

  @override
  String get selectiveBackupSaved => 'Backup saved';

  @override
  String get selectiveBackupSchoolSites => 'School sites';

  @override
  String get selectiveBackupSearch => 'Search objects';

  @override
  String get selectiveBackupSelectAll => 'Select all';

  @override
  String selectiveBackupSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectiveBackupSettings => 'Settings groups';

  @override
  String get selectiveBackupSkills => 'Skills';

  @override
  String get selectiveBackupTimetables => 'Timetables';

  @override
  String get selectiveBackupTimetableSettings => 'Timetable settings';

  @override
  String get selectiveBackupTitle => 'Selective backup and restore';

  @override
  String get selectiveBackupUnavailable =>
      'Could not finish this operation. Check storage access and retry; an unfinished restore will continue from its saved progress.';

  @override
  String get selectiveBackupWorkspaceSettings => 'Workspace settings';

  @override
  String get agentEditAndRedo => 'Edit and redo';

  @override
  String get agentRegenerateReply => 'Regenerate reply';

  @override
  String get agentHistoryVersions => 'Message history';

  @override
  String get agentPreviousReply => 'Previous reply version';

  @override
  String get agentNextReply => 'Next reply version';

  @override
  String agentReplyVersion(int current, int total) {
    return '$current/$total';
  }

  @override
  String get agentRedoExplanation =>
      'This undoes Agent changes from this entire turn onward, then runs only the edited request. Manual edits and other conversations are preserved.';

  @override
  String get agentRedoPending =>
      'History redo is unfinished. Continue this operation before sending another request.';

  @override
  String get agentRedoConflict =>
      'The complete turn cannot be safely undone. Keep the current data and revise your request, or cancel.';

  @override
  String get agentKeepAndRevise => 'Keep data and revise';

  @override
  String get selectiveBackupDeviceSettings => 'Device settings';

  @override
  String get selectiveBackupDeviceLayout => 'Panel dimensions';

  @override
  String get selectiveBackupDeviceDeveloperUi =>
      'Developer preview preferences';

  @override
  String selectiveBackupDeviceGroupPlatform(String group, String platform) {
    return '$group · $platform';
  }

  @override
  String selectiveBackupDeviceUnsupported(String platform) {
    return 'Device settings from $platform do not apply to this platform. Your local settings will be kept.';
  }

  @override
  String selectiveBackupUnsupportedGroups(int count) {
    return '$count unsupported device settings groups will be skipped';
  }

  @override
  String get agentClearDataWarning =>
      'This permanently deletes timetables, events, settings, school sites, chats and their files, skills, memories, local backups and recovery copies, API keys, and the local school sign-in session, then exits Sked. Exported files in other locations are kept. This cannot be undone.';

  @override
  String get agentActivityCourses => 'Courses';

  @override
  String get agentActivityFreeSlots => 'Free slots';

  @override
  String get agentActivityConflicts => 'Conflict check';

  @override
  String get agentKnowledgeAllTypes => 'All types';

  @override
  String get agentKnowledgeAllStates => 'All states';

  @override
  String get agentKnowledgeDisabled => 'Disabled';

  @override
  String get agentKnowledgeMissingTools => 'Required tools unavailable';

  @override
  String get agentKnowledgeNoMatches => 'No matching items';

  @override
  String get schoolWebAgentImportTask =>
      'Organize and import a timetable from the reviewed school page. Ask me about missing details.';

  @override
  String get schoolWebAgentSourceTitle => 'School page';

  @override
  String get agentKnowledgeFullSource => 'Full source text';

  @override
  String get agentConversationGuidanceTitle => 'Conversation guidance';

  @override
  String get agentConversationGuidanceHint =>
      'Set response preferences to use in all conversations.';

  @override
  String get agentRunLimitsTitle => 'Limits per run';

  @override
  String get agentRunLimitsHint =>
      'Limit model requests, tool calls and token usage for each run.';

  @override
  String get agentHistoryRetentionTitle => 'Chat history retention';

  @override
  String get agentApprovalReviseHint =>
      'Describe the changes in the message box, then choose “Update current request”. The pending changes have not been approved.';
}
