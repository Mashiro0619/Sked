// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Woche $week';
  }

  @override
  String get addCourse => 'Kurs hinzufügen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get multiTimetableSwitch => 'Stundenpläne wechseln';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Aktueller Stundenplan · $weeks Wochen';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Tippen zum Wechseln · $weeks Wochen';
  }

  @override
  String get editTimetable => 'Stundenplan bearbeiten';

  @override
  String get schoolImportResultEditorTitle =>
      'Analysiertes Ergebnis bearbeiten';

  @override
  String get schoolImportParsePageTitle => 'Stundenplan analysieren';

  @override
  String get schoolImportParsePageParsing => 'Wird analysiert…';

  @override
  String get schoolImportParsePageFailed => 'Analyse fehlgeschlagen';

  @override
  String get schoolImportParsePageComplete => 'Analyse abgeschlossen';

  @override
  String get schoolImportParsePageContinue => 'Weiter';

  @override
  String get schoolImportParsePageRawContent => 'Rohantwort';

  @override
  String get schoolImportParsePageExpandRaw => 'Rohantwort erweitern';

  @override
  String get schoolImportParsePageCollapseRaw => 'Rohantwort reduzieren';

  @override
  String get schoolImportExpandWarnings => 'Importhinweise ausklappen';

  @override
  String get schoolImportCollapseWarnings => 'Importhinweise einklappen';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Einige Kurse finden noch in Woche $week statt.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Aktuellen Stundenplan ersetzen?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Der importierte Stundenplan ersetzt den aktuellen Stundenplan.';

  @override
  String get createTimetable => 'Neuer Stundenplan';

  @override
  String get jumpToWeek => 'Zu Woche springen';

  @override
  String get timetable => 'Stundenplan';

  @override
  String get themeWorkspaceSchedule => 'Termine';

  @override
  String get timetableName => 'Name des Stundenplans';

  @override
  String get timetableNameRequired =>
      'Geben Sie einen Namen für den Stundenplan ein';

  @override
  String get totalWeeks => 'Gesamtwochen';

  @override
  String get delete => 'Löschen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get deleteTimetableTitle => 'Stundenplan löschen';

  @override
  String deleteTimetableMessage(Object name) {
    return '\"$name\" löschen?';
  }

  @override
  String get noTimetableTitle => 'Noch kein Stundenplan';

  @override
  String get noTimetableMessage =>
      'Erstellen Sie einen Stundenplan oder importieren Sie einen aus einer JSON-Datei.';

  @override
  String get importTimetable => 'Stundenplan importieren';

  @override
  String get courseName => 'Kursname';

  @override
  String get location => 'Ort';

  @override
  String get dayOfWeek => 'Tag';

  @override
  String get semesterWeeks => 'Wochen';

  @override
  String get startTime => 'Startzeit';

  @override
  String get endTime => 'Endzeit';

  @override
  String get linkedPeriods => 'Verknüpfte Stunden';

  @override
  String get linkedPeriodsUnmatched =>
      'Keine Stunden passen zur aktuellen Zeit. Tippen Sie, um manuell auszuwählen.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Stunde $start-$end';
  }

  @override
  String get teacherName => 'Lehrkraft';

  @override
  String get credits => 'Leistungspunkte';

  @override
  String get remarks => 'Notizen';

  @override
  String get customFields => 'Benutzerdefinierte Felder';

  @override
  String get customFieldsHint => 'Eine pro Zeile, Format: schlüssel:wert';

  @override
  String get more => 'Mehr';

  @override
  String get selectDayOfWeek => 'Tag auswählen';

  @override
  String get selectSemesterWeeks => 'Wochen auswählen';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get clear => 'Leeren';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get selectLinkedPeriods => 'Verknüpfte Stunden auswählen';

  @override
  String get addCourseTitle => 'Kurs hinzufügen';

  @override
  String get editCourseTitle => 'Kurs bearbeiten';

  @override
  String get editCourseTooltip => 'Kurs bearbeiten';

  @override
  String get place => 'Ort';

  @override
  String get time => 'Zeit';

  @override
  String get notFilled => 'Nicht ausgefüllt';

  @override
  String get none => 'Keine';

  @override
  String get conflictCourses => 'Kurskonflikte';

  @override
  String get locationNotFilled => 'Ort nicht ausgefüllt';

  @override
  String get setAsDisplayed => 'Als angezeigt festlegen';

  @override
  String get editThisCourse => 'Diesen Kurs bearbeiten';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionTimetable => 'Stundenplan';

  @override
  String get settingsSectionGeneralSchedule => 'Terminplan';

  @override
  String get settingsSectionAppearance => 'Darstellung';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionWorkspace => 'Arbeitsbereich';

  @override
  String get settingsSectionAppearanceLanguage => 'Darstellung und Sprache';

  @override
  String get settingsSectionDataSecurity => 'Daten und Sicherheit';

  @override
  String get settingsSectionAbout => 'Über Sked';

  @override
  String get noTimetableSettings =>
      'Derzeit ist kein Stundenplan für die Einstellungen verfügbar.';

  @override
  String get semesterStartDate => 'Semesterbeginn';

  @override
  String get periodTimeSets => 'Stundenzeiten-Set';

  @override
  String get noPeriodTimeAvailable => 'Kein verfügbares Stundenzeiten-Set';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count Stunden';
  }

  @override
  String get coursePopupDismissSetting =>
      'Tippen außerhalb erlaubt, um das Kurs-Popup zu schließen';

  @override
  String get coursePopupDismissSettingHint =>
      'Wenn dies deaktiviert ist, wird auch das Schließen per Wischen nach unten deaktiviert.';

  @override
  String get preserveTimetableGaps => 'Lücken im Stundenplan beibehalten';

  @override
  String get preserveTimetableGapsHint =>
      'Wenn deaktiviert, werden Mittags- und Pausenlücken eingeklappt, damit spätere Kurse nach oben rücken.';

  @override
  String get showPastEndedCourses => 'Bereits beendete Kurse anzeigen';

  @override
  String get showPastEndedCoursesHint =>
      'Zeigt Kurse, die nach der aktuellen realen Woche bereits beendet sind, in einem helleren Graustil an.';

  @override
  String get showFutureCourses => 'Zukünftige Kurse anzeigen';

  @override
  String get showFutureCoursesHint =>
      'Zeigt Kurse, die diese Woche nicht aktiv sind, aber in späteren Wochen erscheinen, in einem Graustil an.';

  @override
  String get timetableDisplaySettings =>
      'Anzeige und Interaktion des Stundenplans';

  @override
  String get timetableDisplaySettingsDesc =>
      'Kursanzeige, Layout, Wochengesten und Schnellzugriff';

  @override
  String get showTimetableGridLines => 'Gitterlinien im Stundenplan anzeigen';

  @override
  String get showTimetableGridLinesHint =>
      'Legt fest, ob horizontale und vertikale Gitterlinien im Stundenplan sichtbar sind.';

  @override
  String get timetableHorizontalLayoutSection =>
      'Horizontale Anordnung und Gesten';

  @override
  String get fitDaySelectorToWidth => 'Tagesauswahl an Bildschirm anpassen';

  @override
  String get fitDaySelectorToWidthHint =>
      'Zeigt nach Möglichkeit alle sieben Tage auf dem Bildschirm. Deaktivieren Sie diese Option, um eine feste Breite zu verwenden und zu scrollen.';

  @override
  String get fitWeekColumnsToWidth => 'Wochenspalten an Bildschirm anpassen';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Zeigt nach Möglichkeit alle sieben Stundenplanspalten auf dem Bildschirm. Deaktivieren Sie diese Option, um eine feste Breite zu verwenden und zu scrollen.';

  @override
  String get enableWeekSwipeNavigation => 'Woche durch Wischen wechseln';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Wischen Sie nach links oder rechts, um die Woche zu wechseln. Bei festen Spaltenbreiten müssen Sie zuerst über den Rand hinausziehen.';

  @override
  String get liveCourseOutlineColor => 'Konturfarbe des Kurses';

  @override
  String get liveCourseOutlineColorHint =>
      'Wählen Sie, ob Konturen den aktuellen/nächsten Kurs oder alle aktuell angezeigten Kurse hervorheben.';

  @override
  String get liveCourseOutlineSettings => 'Kurskontur';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Legen Sie fest, ob die Kontur aktiviert ist, worauf sie zielt, ob sie der Themenfarbe folgt und welche effektive Konturfarbe verwendet wird.';

  @override
  String get liveCourseOutlineEnabled => 'Kontur aktivieren';

  @override
  String get liveCourseOutlineFollowTheme => 'Themenfarbe folgen';

  @override
  String get liveCourseOutlineTarget => 'Konturziel';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Aktueller/nächster Kurs';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Alle angezeigten Kurse';

  @override
  String get liveCourseOutlineEffectiveColor => 'Effektive Farbe';

  @override
  String get liveCourseOutlineCustomColor => 'Benutzerdefinierte Konturfarbe';

  @override
  String get liveCourseOutlineWidth => 'Konturstärke';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Sprache';

  @override
  String get languagePageDescription =>
      'Wählen Sie eine der Sprachen aus, die in der App tatsächlich verfügbar sind.';

  @override
  String get languageChinese => 'Chinesisch';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API-Antwort';

  @override
  String get theme => 'Design';

  @override
  String get themeFollowSystem => 'Systemeinstellung folgen';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeColor => 'Designfarbe';

  @override
  String get themeColorModeSingle => 'Einzelne Designfarbe';

  @override
  String get themeColorModeColorful => 'Farbenfroh';

  @override
  String get themeColorUiColors => 'UI-Farben';

  @override
  String get themeColorCourseColors => 'Kursfarben';

  @override
  String get themeColorPrimary => 'Primär';

  @override
  String get themeColorSecondary => 'Sekundär';

  @override
  String get themeColorTertiary => 'Tertiär';

  @override
  String get themeColorCourseText => 'Kurstext';

  @override
  String get themeColorCourseTextAuto => 'Automatisch';

  @override
  String get themeColorCourseTextCustom => 'Benutzerdefinierte Farbe';

  @override
  String get themeColorCourseColorsEmpty =>
      'Kursfarben werden nach dem Import eines Stundenplans generiert.';

  @override
  String get themeCustomColor => 'Benutzerdefinierte Farbe';

  @override
  String get themeApplyCustomColor => 'Farbe anwenden';

  @override
  String get themeApplySettings => 'Einstellungen anwenden';

  @override
  String get dataImportExport => 'Daten importieren und exportieren';

  @override
  String get dataImportExportDesc =>
      'Importieren Sie alle Daten oder einzelne Stundenpläne oder exportieren Sie den aktuellen/alle Stundenpläne.';

  @override
  String get appBackupTitle => 'App-Sicherung und Wiederherstellung';

  @override
  String get appBackupSubtitle =>
      'Sichere oder stelle Stundenpläne, Terminpläne, Einstellungen und Schul-Websites wieder her. API-Schlüssel sind nicht enthalten.';

  @override
  String get appBackupSheetSubtitle =>
      'Eine vollständige Wiederherstellung ersetzt die aktuellen App-Daten. AI-API-Schlüssel liegen im sicheren Speicher und werden nicht in Sicherungsdateien geschrieben.';

  @override
  String get restoreBackupFileTitle => 'Aus JSON-Datei wiederherstellen';

  @override
  String get restoreBackupFileSubtitle =>
      'Wähle eine vollständige Sked-Sicherungsdatei. Vor der Wiederherstellung musst du bestätigen.';

  @override
  String get restoreBackupTextTitle => 'Sicherungs-JSON einfügen';

  @override
  String get restoreBackupTextSubtitle =>
      'Füge eine vollständige Sicherung ein und stelle die aktuellen App-Daten wieder her.';

  @override
  String get shareBackupTitle => 'Sicherungsdatei teilen';

  @override
  String get shareBackupSubtitle =>
      'Exportiere alle App-Daten als JSON. API-Schlüssel werden ausgeschlossen.';

  @override
  String get saveBackupTitle => 'Sicherungsdatei speichern';

  @override
  String get saveBackupSubtitle =>
      'Speichere eine vollständige App-Sicherung in einer lokalen Datei.';

  @override
  String get copyBackupTitle => 'Sicherungstext kopieren';

  @override
  String get copyBackupSubtitle =>
      'Zeigt das vollständige Sicherungs-JSON an, damit du es kopieren oder vorübergehend speichern kannst.';

  @override
  String get restoreBackupConfirmTitle =>
      'Vollständige Sicherung wiederherstellen?';

  @override
  String get restoreBackupConfirmMessage =>
      'Dies ersetzt alle aktuellen Stundenpläne, allgemeinen Terminpläne, Einstellungen und Schul-Websites. API-Schlüssel werden nicht aus Sicherungen importiert; gib den Schlüssel erneut ein, bevor du wieder Stundenpläne analysierst.';

  @override
  String get restoreBackupConfirmAction => 'Sicherung wiederherstellen';

  @override
  String get restoreBackupSuccessMessage =>
      'Vollständige App-Sicherung wiederhergestellt. AI-API-Schlüssel müssen erneut eingegeben werden.';

  @override
  String get restoreBackupFailureMessage =>
      'Wiederherstellung fehlgeschlagen. Prüfe den Inhalt der Sicherung und versuche es erneut.';

  @override
  String get openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get openSourceLicensesDesc =>
      'Lizenzen für Flutter-Abhängigkeiten und gebündelte App-Icon-Ressourcen anzeigen.';

  @override
  String get checkForUpdates => 'Nach Updates suchen';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String get microsoftStoreUpdates =>
      'Updates werden über den Microsoft Store verwaltet';

  @override
  String get includePrereleaseUpdates => 'Vorabversionen erhalten';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Auch Alpha-, Beta- und RC-Versionen berücksichtigen, die instabil sein können. Ausgeschaltet werden nur stabile Versionen angeboten.';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Sie verwenden bereits die neueste Version ($version)';
  }

  @override
  String get currentVersionLabel => 'Aktuelle Version';

  @override
  String get newVersionAvailable => 'Update verfügbar';

  @override
  String get latestVersionLabel => 'Neueste Version';

  @override
  String get updateContentLabel => 'Update-Details';

  @override
  String get officialWebsite => 'Offizielle Website';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Cloud-Speicher';

  @override
  String get ignoreThisVersion => 'Diese Version ignorieren';

  @override
  String get openUpdatesFailed => 'Update-Link konnte nicht geöffnet werden';

  @override
  String get updateCheckFailedTitle => 'Update-Prüfung fehlgeschlagen';

  @override
  String get updateCheckFailedMessage =>
      'Die neueste Version konnte nicht von GitHub abgerufen werden. Sie können unten trotzdem die GitHub-Releases öffnen.';

  @override
  String get githubRepository => 'GitHub-Repository';

  @override
  String get googlePlayStoreDesc => 'Sked bei Google Play ansehen';

  @override
  String get openGooglePlayFailed => 'Google Play konnte nicht geöffnet werden';

  @override
  String get starSkedOnGithub => 'Geben Sie Sked einen Stern auf GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Öffnen Sie das Projekt-Repository und geben Sie Sked einen Stern';

  @override
  String get openGithubFailed =>
      'Der Link zum GitHub-Repository konnte nicht geöffnet werden';

  @override
  String get openPrivacyPolicyFailed =>
      'Der Link zur Datenschutzrichtlinie konnte nicht geöffnet werden';

  @override
  String get selectPeriodTimeSet => 'Stundenzeiten-Set auswählen';

  @override
  String get newItem => 'Neu';

  @override
  String get editPeriodTimeSet => 'Stundenzeiten-Set bearbeiten';

  @override
  String get importTimetableFiles => 'Stundenplan importieren';

  @override
  String get importTimetableFilesDesc =>
      'Unterstützt eine oder mehrere Stundenplan-Dateien.';

  @override
  String get importTimetableText => 'Stundenplan aus Text importieren';

  @override
  String get importTimetableTextDesc =>
      'Fügen Sie den JSON-Inhalt des Stundenplans ein und importieren Sie ihn.';

  @override
  String get shareTimetableFiles => 'Stundenplan-Dateien teilen';

  @override
  String get shareTimetableFilesDesc =>
      'Wählen Sie zuerst einen oder mehrere Stundenpläne aus.';

  @override
  String get saveTimetableFiles => 'Stundenplan-Dateien speichern';

  @override
  String get saveTimetableFilesDesc =>
      'Wählen Sie zuerst einen oder mehrere Stundenpläne aus.';

  @override
  String get exportTimetableText => 'Stundenplan als Text exportieren';

  @override
  String get exportTimetableTextDesc =>
      'Wählen Sie einen oder mehrere Stundenpläne und kopieren Sie dann den JSON-Inhalt.';

  @override
  String get jsonContent => 'JSON-Inhalt';

  @override
  String get pasteJsonContentHint =>
      'Fügen Sie den JSON-Inhalt zum Importieren ein.';

  @override
  String get jsonContentEmpty => 'Fügen Sie zuerst den JSON-Inhalt ein.';

  @override
  String get copyText => 'Kopieren';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get share => 'Teilen';

  @override
  String get selectTimetablesToExport =>
      'Zu exportierende Stundenpläne auswählen';

  @override
  String get selectTimetablesToImport =>
      'Zu importierende Stundenpläne auswählen';

  @override
  String timetableCourseCount(int count) {
    return '$count Kurse';
  }

  @override
  String get importAction => 'Importieren';

  @override
  String get importTimetableDialogTitle => 'Stundenplan importieren';

  @override
  String get chooseImportMethod => 'Wählen Sie, wie importiert werden soll.';

  @override
  String get importAsNewTimetable => 'Als neuen Stundenplan importieren';

  @override
  String get replaceCurrentTimetable => 'Aktuellen Stundenplan ersetzen';

  @override
  String get importPeriodTimeSetDialogTitle => 'Stundenzeiten-Sets importieren';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Diese Datei enthält gebündelte Stundenzeiten-Sets. Möchten Sie sie importieren und verknüpfen?';

  @override
  String get importBundledPeriodTimeSets => 'Importieren und verknüpfen';

  @override
  String get discardBundledPeriodTimeSets => 'Gebündelte Sets verwerfen';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Es ist kein vorhandenes Stundenzeiten-Set verfügbar, daher können gebündelte Stundenzeiten-Sets nicht verworfen werden.';

  @override
  String savedToPath(Object path) {
    return 'Gespeichert unter $path';
  }

  @override
  String get saveCancelled => 'Speichern abgebrochen';

  @override
  String get fileSaveRestrictedTitle => 'Dateispeicherung eingeschränkt';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Das System konnte die Datei nicht speichern. Sie können es erneut versuchen oder stattdessen die Teilen-Funktion verwenden.';

  @override
  String get retrySave => 'Speichern erneut versuchen';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Aktivieren Sie den Dateizugriff in den Systemeinstellungen und versuchen Sie den Export dann erneut.';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get browserDownloadRestrictedTitle => 'Browser-Download eingeschränkt';

  @override
  String get browserDownloadRestrictedMessage =>
      'Dieser Browser unterstützt kein direktes Speichern in eine lokale Datei. Prüfen Sie die Download-Berechtigungen des Browsers oder verwenden Sie stattdessen Dateifreigabe.';

  @override
  String get switchToShare => 'Stattdessen teilen';

  @override
  String get fileSaveFailedTitle => 'Datei konnte nicht gespeichert werden';

  @override
  String get fileSaveFailedWindowsMessage =>
      'In den aktuellen Pfad kann nicht geschrieben werden. Der Zielordner ist möglicherweise geschützt, die Datei wird verwendet oder der Pfad ist nicht beschreibbar.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Das System konnte die Datei nicht speichern. Sie können es erneut versuchen, die Systemeinstellungen prüfen oder stattdessen Dateifreigabe verwenden.';

  @override
  String get retryLater => 'Später erneut versuchen';

  @override
  String get exportSwitchedToShare =>
      'Für den Export wurde zur Dateifreigabe gewechselt';

  @override
  String get saveFailedRetry =>
      'Speichern fehlgeschlagen. Bitte versuchen Sie es später erneut.';

  @override
  String get periodTimesUnsavedExitTitle => 'Änderungen nicht gespeichert';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Die letzten Änderungen an den Unterrichtszeiten konnten nicht gespeichert werden. Sie können es erneut versuchen, weiterbearbeiten oder die Änderungen verwerfen.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Einige Unterrichtszeiten sind ungültig. Korrigieren Sie sie vor dem Speichern oder verwerfen Sie die Änderungen und verlassen Sie die Seite.';

  @override
  String get discardChangesAndExit => 'Verwerfen und verlassen';

  @override
  String get appInstanceBlockedTitle => 'Sked ist bereits geöffnet';

  @override
  String get appInstanceBlockedMessage =>
      'Ein anderes Sked-Fenster oder ein anderer Browser-Tab verwendet deine lokalen Daten. Schließe das Fenster bzw. den Tab und versuche es erneut.';

  @override
  String get appInstanceLeaseFailedTitle => 'Lokale Daten sind nicht verfügbar';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked konnte den exklusiven Zugriff auf lokale Daten nicht bestätigen. Deine Daten wurden weder geöffnet noch geändert. Prüfe den Speicherzugriff und versuche es erneut.';

  @override
  String get savingChanges => 'Änderungen werden gespeichert...';

  @override
  String get showApiKey => 'API-Schlüssel anzeigen';

  @override
  String get hideApiKey => 'API-Schlüssel ausblenden';

  @override
  String get importFailedCheckContent =>
      'Import fehlgeschlagen. Bitte prüfen Sie den Dateiinhalt.';

  @override
  String get noImportableTimetables =>
      'In der importierten Datei wurden keine verwendbaren Stundenpläne gefunden.';

  @override
  String importedTimetablesCount(int count) {
    return '$count Stundenpläne importiert';
  }

  @override
  String get periodTimesTitle => 'Stundenzeiten';

  @override
  String get importExport => 'Import und Export';

  @override
  String get importPeriodTemplate => 'Stundenvorlage importieren';

  @override
  String get importPeriodTemplateText => 'Stundenvorlage aus Text importieren';

  @override
  String get sharePeriodTemplate => 'Stundenvorlage teilen';

  @override
  String get saveTemplateToFile => 'Vorlage in Datei speichern';

  @override
  String get exportPeriodTemplateText => 'Stundenvorlage als Text exportieren';

  @override
  String get deletePeriodTimeSet => 'Stundenzeiten-Set löschen';

  @override
  String get periodTimeSetName => 'Name des Stundenzeiten-Sets';

  @override
  String get addOnePeriod => 'Stunde hinzufügen';

  @override
  String periodNumberLabel(int index) {
    return 'Stunde $index';
  }

  @override
  String get deleteThisPeriod => 'Diese Stunde löschen';

  @override
  String durationMinutes(int minutes) {
    return 'Dauer $minutes Min.';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Abstand zur vorherigen $minutes Min.';
  }

  @override
  String get endTimeMustBeLater => 'Die Endzeit muss nach der Startzeit liegen';

  @override
  String get periodOverlapPrevious =>
      'Diese Stunde überschneidet sich mit der vorherigen';

  @override
  String get periodTimesSaved => 'Stundenzeiten gespeichert';

  @override
  String get deletePeriodTimeSetTitle => 'Stundenzeiten-Set löschen';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return '\"$name\" löschen?';
  }

  @override
  String get currentPeriodTimeSet => 'aktuelles Stundenzeiten-Set';

  @override
  String importedPeriodTimesCount(int count) {
    return '$count Stundenzeiten importiert';
  }

  @override
  String get periodFilePermissionTitle => 'Dateiberechtigung erforderlich';

  @override
  String get androidFilePermissionMessage =>
      'Für den Export unter Android ist eine Dateizugriffsberechtigung erforderlich. Erteilen Sie die Berechtigung, um das Speichern fortzusetzen.';

  @override
  String get reauthorize => 'Erneut autorisieren';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Berechtigung dauerhaft verweigert';

  @override
  String get permissionSettingsExportMessage =>
      'Aktivieren Sie den Dateizugriff in den Systemeinstellungen und versuchen Sie den Export dann erneut.';

  @override
  String get privacyPolicyTitle => 'Datenschutzrichtlinie';

  @override
  String get privacyPolicyEntryDesc =>
      'Erfahren Sie, wie die App lokalen Speicher, Schulwebsite-Konfiguration, Dateiimport/-export, Webseitenanalyse und externe Links verarbeitet.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Akzeptierte Version: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked ist ein lokal ausgerichtetes Stundenplan-Werkzeug. Stundenpläne, Stundenzeiten-Sets und Schulwebsite-Konfigurationen werden nur auf Ihrem Gerät oder in Ihrem Browser gespeichert und niemals automatisch hochgeladen. Die App verarbeitet Daten nur, wenn Sie ausdrücklich Aktionen wie Import, Webseitenanalyse, Teilen oder das Öffnen externer Links starten. Die vollständige Datenschutzrichtlinie ist online verfügbar.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Lokaler Speicher';

  @override
  String get privacyPolicyLocalStorageBody =>
      'Auf nativen Plattformen speichert Sked Stundenpläne, Terminpläne, zugehörige Einstellungen und bearbeitbare Schulwebsite-Konfigurationen im Anwendungsdatenverzeichnis des Betriebssystems. Im Browser wird der Browserspeicher verwendet. Dateien, die frühere Versionen im Dokumente-Ordner des Benutzers abgelegt haben, bleiben erhalten, werden aber nicht automatisch gelesen oder übernommen. Exportieren Sie vor dem Upgrade eine vollständige App-Sicherung aus der alten Version und stellen Sie diese anschließend wieder her, um die Daten zu behalten. Die KI-API-Einstellungen werden lokal gespeichert. Der benutzerdefinierte API-Schlüssel wird nach Möglichkeit im sicheren Speicher der Plattform abgelegt. Vollständige App-Sicherungen enthalten den benutzerdefinierten API-Schlüssel nicht. Die App lädt diese lokalen Daten nicht automatisch auf einen vom Entwickler betriebenen Server hoch.';

  @override
  String get privacyPolicyImportExportTitle => 'Import und Export';

  @override
  String get privacyPolicyImportExportBody =>
      'Die App liest oder schreibt Stundenplan-JSON-Dateien, Schulwebsite-JSON-Dateien und Periodenvorlagen-Dateien nur, wenn Sie ausdrücklich eine Datei auswählen oder einen Export starten. Das Importieren dieser Dateien ist ein lokaler Vorgang, es sei denn, Sie wählen zusätzlich die Webseitenanalyse. Das Abrufen einer benutzerdefinierten Modellliste ist ebenfalls eine ausdrückliche Netzwerkaktion und kontaktiert nur den von Ihnen konfigurierten benutzerdefinierten Endpunkt.';

  @override
  String get privacyPolicySharingTitle => 'Teilen';

  @override
  String get privacyPolicySharingBody =>
      'Wenn Sie ausdrücklich die Teilen-Funktion verwenden, übergibt die App die exportierte Datei an das System-Freigabeblatt oder an die von Ihnen gewählte Ziel-App. Wie diese Datei anschließend verarbeitet wird, hängt von der gewählten Ziel-App oder dem Dienst ab.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Externe Links';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Wenn Sie externe Links wie das GitHub-Repository öffnen, übergibt die App die Aktion an Ihren Browser oder eine andere externe Anwendung. Die weitere Datenverarbeitung unterliegt dann dem jeweiligen Drittanbieter.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Was die App nicht sammelt';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Die App benötigt kein Sked-Konto und aktiviert weder Analysen noch Werbe-IDs oder Cloud-Backups. Außerdem gibt es kein spezielles Feld zum Erfassen von Schulzugangspasswörtern. Wenn Sie sich innerhalb der App auf einer Schulwebsite anmelden, findet diese Interaktion auf der von Ihnen geöffneten Schulseite statt.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Webseitenanalyse';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Wenn du den Import einer Schul-Webseite verwendest oder eingefügten Stundenplantext / HTML analysierst, bereitet und bereinigt die App den Inhalt zuerst lokal und sendet anschließend den übermittelten Stundenplantext, Seitentext oder HTML-Inhalt, optionalen Seitentitel und URL, die aktuelle App-Sprache sowie den Parser-Prompt an den von dir konfigurierten OpenAI-kompatiblen Endpunkt. Auch das Abrufen der Modellliste fragt denselben Endpunkt an. Sked stellt keinen integrierten Parser-Endpunkt bereit und sendet keine Analyseanfragen an ein vom Entwickler kontrolliertes Stundenplan-Parser-Backend. Der benutzerdefinierte Endpunkt und mögliche Upstream-Dienste können Daten nach den Regeln des von dir gewählten Dienstanbieters speichern, weiterleiten, begrenzen, löschen oder anderweitig verarbeiten. Wenn du eine http:// Base URL verwendest, nutze sie nur auf vertrauenswürdigen Geräten, in vertrauenswürdigen Netzwerken und mit vertrauenswürdigen Endpunktdiensten, da Inhalte und API-Schlüssel möglicherweise nicht durch Transportverschlüsselung geschützt sind.';

  @override
  String get privacyPolicyUpdatesTitle => 'Richtlinien-Updates';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Die aktuelle Version der Datenschutzrichtlinie ist $version. Wenn eine spätere Version die Datenverarbeitung ändert, fordert die App Sie möglicherweise auf, die aktualisierte Richtlinie erneut zu lesen und zu akzeptieren.';
  }

  @override
  String get privacyGateTitle =>
      'Bitte stimmen Sie der Datenschutzrichtlinie zu, bevor Sie die App verwenden';

  @override
  String get privacyGateSummaryStorage =>
      'Stundenpläne, Stundenzeiten-Sets und Schulwebsite-Konfigurationen werden nur lokal gespeichert und nicht automatisch auf einen Entwickler-Server hochgeladen.';

  @override
  String get privacyGateSummaryImportExport =>
      'Import, Export und Teilen erfolgen nur, wenn Sie diese ausdrücklich starten; die Webseitenanalyse sendet nur den von Ihnen eingereichten komprimierten Inhalt an den konfigurierten Analyse-Endpunkt, und Sie können den analysierten Stundenplan vor dem Speichern überprüfen.';

  @override
  String get privacyGateSummaryUpdates =>
      'Wenn eine spätere Version die Datenverarbeitung ändert, fordert die App Sie möglicherweise auf, die aktualisierte Datenschutzrichtlinie erneut zu prüfen.';

  @override
  String get schoolWebImportEntry => 'Von Schulwebseite importieren';

  @override
  String get schoolWebImportEntryDesc =>
      'Importieren Sie die aktuelle Stundenplanseite von der Schulwebsite.';

  @override
  String get schoolSitesManageEntry => 'Schulwebsites verwalten';

  @override
  String get schoolSitesManageEntryDesc =>
      'Login-URLs für Schulen hinzufügen, bearbeiten und löschen, mit JSON-Import und -Export.';

  @override
  String get schoolSitesPageTitle => 'Verwaltung der Schulwebsites';

  @override
  String get schoolSitesImportJson => 'Schul-JSON importieren';

  @override
  String get schoolSitesShareJson => 'Schul-JSON teilen';

  @override
  String get schoolSitesSaveJson => 'Schul-JSON speichern';

  @override
  String get schoolSitesSaved => 'Schulwebsites gespeichert';

  @override
  String get schoolSitesImported => 'Schulwebsites importiert';

  @override
  String get schoolSitesImportPreviewTitle => 'Import der Schulwebsites prüfen';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount gültige Websites, $invalidCount ungültige Einträge.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Die Datei enthält eine leere Liste von Schulwebsites.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Eintrag $position ist ungültig und wird übersprungen.';
  }

  @override
  String get schoolSitesImportMerge => 'Zusammenführen';

  @override
  String get schoolSitesImportReplace => 'Ersetzen';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Aktuelle Schulwebsites ersetzen?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Dabei werden $currentCount vorhandene Websites entfernt und $importedCount importierte Websites gespeichert. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Schulwebsite-Daten müssen wiederhergestellt werden';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked konnte weder die Schulwebsite-Datei noch deren Sicherung lesen. Vor dem Sperren weiterer Schreibzugriffe wurden geschützte Kopien erstellt.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Speicher für Schulwebsites nicht verfügbar';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked kann derzeit nicht auf den Speicher der Schulwebsites zugreifen. Prüfen Sie den Speicherzugriff und die Verfügbarkeit des Geräts und versuchen Sie es erneut. Die vorhandenen Website-Daten werden nicht überschrieben.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Wiederherstellungsdateien und betroffene Speicherorte sind unten aufgeführt. Verändern Sie diese Dateien nicht, bis die Website-Liste wiederhergestellt ist.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Ohne Schulwebsites neu beginnen';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Mit einer leeren Schulwebsite-Liste beginnen?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Die geschützten Kopien bleiben erhalten, aber Sked erstellt eine neue, leere Schulwebsite-Datei. Fahren Sie nur fort, wenn Sie die Wiederherstellung nicht zuerst erneut versuchen möchten.';

  @override
  String get schoolSitesEmpty =>
      'Noch keine Schulwebsite-Konfiguration vorhanden.';

  @override
  String get schoolSitesNameLabel => 'Name der Schule';

  @override
  String get schoolSitesLoginUrlLabel => 'Login-URL';

  @override
  String get schoolSitesAdd => 'Schule hinzufügen';

  @override
  String get schoolSitesEdit => 'Schule bearbeiten';

  @override
  String get schoolSitesDeleteTitle => 'Schule löschen';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return '\"$name\" löschen?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Füllen Sie zuerst den Schulnamen und die Login-URL aus.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Import durch Einfügen des Stundenplan-Seiteninhalts';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Fügen Sie manuell den Quellcode oder den Rohinhalt einer Seite mit Stundenplaninformationen ein.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Stundenplan aus Seiteninhalt analysieren';

  @override
  String get schoolHtmlImportUrlLabel => 'Quell-URL (optional)';

  @override
  String get schoolHtmlImportTitleLabel => 'Seitentitel (optional)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Seiteninhalt';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Fügen Sie hier den Quellcode oder den Rohinhalt einer Seite mit Stundenplaninformationen ein.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Jeder Inhalt mit Stundenplaninformationen kann analysiert und importiert werden, nicht nur HTML.';

  @override
  String get schoolHtmlImportCompress => 'Inhalt vorbereiten';

  @override
  String get schoolHtmlImportCompressed => 'Inhalt vorbereitet';

  @override
  String get schoolHtmlImportCompressFirst =>
      'Bereiten Sie zuerst den Inhalt vor.';

  @override
  String get schoolHtmlImportSubmit => 'Analysieren und importieren';

  @override
  String get schoolImportContentTruncated =>
      'Diese Seite hat das sichere Importlimit erreicht. Nur der erfasste Teil wird zur Analyse gesendet.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Die Analyse kann etwas dauern. Bitte warten.';

  @override
  String get schoolHtmlImportEmpty => 'Fügen Sie zuerst das Seiten-HTML ein.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Zurück zur Webseite';

  @override
  String get schoolWebImportPageTitle => 'Import von Schulwebseite';

  @override
  String get schoolWebImportPreview => 'Importvorschau';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count Kurse';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count Stunden';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Seitentitel';

  @override
  String get schoolWebImportParserUsed => 'Parser';

  @override
  String get schoolWebImportWarnings => 'Importhinweise';

  @override
  String get schoolWebImportParserDetails => 'Analysedetails';

  @override
  String get schoolWebImportExpandParserDetails => 'Analysedetails einblenden';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Analysedetails ausblenden';

  @override
  String get schoolWebImportOpenPageHint =>
      'Melden Sie sich in der App auf der Schulwebsite an und navigieren Sie dann manuell zur Stundenplanseite.';

  @override
  String get schoolWebImportConfigMissing =>
      'Die Konfiguration des benutzerdefinierten Parsers ist unvollständig. Geben Sie zuerst Basis-URL, API-Schlüssel und Modell an.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Diese Plattform unterstützt noch keine eingebettete Web-Anmeldung. Bitte verwenden Sie eine Plattform mit WebView-Unterstützung.';

  @override
  String get schoolWebImportSelectSchool => 'Schule auswählen';

  @override
  String get schoolWebImportNoSchools =>
      'Keine Schulkonfiguration verfügbar. Prüfen Sie zuerst school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Schulkonfiguration konnte nicht geladen werden. Prüfen Sie das JSON-Dateiformat.';

  @override
  String get schoolWebImportImportCurrentPage => 'Aktuelle Seite importieren';

  @override
  String get schoolWebImportLoadingPage => 'Seite wird geladen…';

  @override
  String get schoolWebImportParsing => 'Aktuelle Seite wird analysiert…';

  @override
  String get schoolWebImportLoadFailed =>
      'Seite konnte nicht geladen werden. Bitte aktualisieren Sie die Seite oder versuchen Sie es später erneut.';

  @override
  String get schoolWebImportUnknownOrigin => 'Unbekannte Website';

  @override
  String get schoolWebImportExitTitle => 'Browser verlassen?';

  @override
  String get schoolWebImportExitMessage =>
      'Die Seite wird geschlossen. Alles, was Sie noch nicht importiert haben, geht verloren.';

  @override
  String get schoolWebImportExitConfirm => 'Verlassen';

  @override
  String get schoolWebImportEmptyPage =>
      'Der aktuelle Seiteninhalt ist leer und kann noch nicht importiert werden.';

  @override
  String get schoolWebImportSuccess => 'Web-Stundenplan importiert';

  @override
  String get schoolImportParserSettingsTitle => 'API für Stundenplanimport';

  @override
  String get schoolImportParserSettingsDesc =>
      'Konfiguriere die OpenAI-kompatible API für den Stundenplanimport, nicht für einen Chat-Assistenten.';

  @override
  String get schoolImportParserSourceTitle => 'Parser-Quelle';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Benutzerdefiniert OpenAI-kompatibel';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Benutzerdefinierter OpenAI-kompatibler Parser';

  @override
  String get schoolImportParserCustomPromptTitle =>
      'Benutzerdefinierter Prompt';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Bearbeiten Sie hier den integrierten Parser-Prompt. Änderungen betreffen nur den benutzerdefinierten OpenAI-kompatiblen Parser.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Der integrierte Prompt wird hier standardmäßig geladen. Leeren Sie ihn, um auf die integrierte Version zurückzufallen.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Standard-Prompt zurücksetzen';

  @override
  String get schoolImportParserBaseUrl => 'Basis-URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Die Base URL muss eine HTTP- oder HTTPS-Adresse mit Host sein.';

  @override
  String get schoolImportParserApiKey => 'API-Schlüssel';

  @override
  String get schoolImportParserModel => 'Modell';

  @override
  String get schoolImportParserFetchModels => 'Modellliste abrufen';

  @override
  String get schoolImportParserFetchingModels => 'Modelle werden abgerufen...';

  @override
  String get schoolImportParserNoModelsFound =>
      'Der Endpunkt hat keine Modelle zurückgegeben.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Modelle konnten nicht abgerufen werden. Prüfe den Endpunkt und versuche es erneut.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return '$count Modelle abgerufen';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'Der benutzerdefinierte API-Schlüssel wird nach Möglichkeit im sicheren Speicher der Plattform abgelegt. Verwenden Sie eigene Parser-Zugangsdaten und HTTP-Endpunkte nur auf Geräten, in Browsern und in Netzwerken, denen Sie vertrauen.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Unverschlüsselten HTTP-Endpunkt verwenden?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'Der API-Schlüssel und die Stundenplandaten können während der Übertragung gelesen oder verändert werden. Fahren Sie nur fort, wenn Sie diesem Gerät, Netzwerk und Endpunkt vertrauen. Diese Zustimmung gilt, bis Sie Sked schließen.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Die Konfiguration des benutzerdefinierten Parsers ist unvollständig. Füllen Sie zuerst Base URL, API key und Modell aus.';

  @override
  String get clearAppData => 'Daten löschen';

  @override
  String get clearAppDataDesc =>
      'Alle lokalen Sked-Daten endgültig löschen und die App beenden';

  @override
  String get clearAppDataConfirmTitle => 'Alle Sked-Daten löschen?';

  @override
  String get clearAppDataConfirmMessage =>
      'Dabei werden Stundenpläne, Terminpläne, Einstellungen, Schulwebsites, lokale Sicherungen, Wiederherstellungskopien und der KI-API-Schlüssel endgültig gelöscht. Anschließend wird Sked beendet. Dateien, die Sie an andere Orte exportiert haben, werden nicht gelöscht. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get clearAppDataAction => 'Daten löschen und beenden';

  @override
  String get clearAppDataFailed =>
      'Nicht alle lokalen Daten konnten gelöscht werden. Sked bleibt geöffnet, damit Sie es erneut versuchen können.';

  @override
  String get clearAppDataExitFailed =>
      'Die lokalen Daten wurden gelöscht, aber Sked konnte nicht beendet werden. Schließen Sie die App manuell, bevor Sie sie erneut verwenden.';

  @override
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'Parser: Benutzerdefiniert ($model)';
  }

  @override
  String get privacyViewFullPolicy =>
      'Vollständige Datenschutzrichtlinie anzeigen';

  @override
  String get privacyAgreeAndContinue => 'Zustimmen und fortfahren';

  @override
  String get privacyDecline => 'Ablehnen';

  @override
  String get privacyDeclineWebHint =>
      'Diese Browserumgebung erlaubt es der App nicht, die Seite für Sie zu schließen. Wenn Sie nicht zustimmen, schließen Sie bitte diesen Tab oder dieses Fenster selbst.';

  @override
  String get defaultPeriodTimeSetName => 'Standardstunden';

  @override
  String get periodTimeSetFallbackName => 'Stundenzeiten';

  @override
  String get untitledTimetableName => 'Unbenannter Stundenplan';

  @override
  String get newTimetableName => 'Neuer Stundenplan';

  @override
  String get newPeriodTimeSetName => 'Neues Stundenzeiten-Set';

  @override
  String get emptyTimetableName => 'Leerer Stundenplan';

  @override
  String importedPeriodTimeSetName(Object name) {
    return '$name-Stunden';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Der Typ der Importdatei stimmt nicht überein.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Diese Version der Importdatei wird noch nicht unterstützt.';

  @override
  String get noPeriodTimesInImportMessage =>
      'In der Importdatei wurden keine Stundenzeiten gefunden.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Bitte wählen Sie mindestens einen Stundenplan aus.';

  @override
  String get noExportableTimetableMessage =>
      'Es ist kein Stundenplan zum Exportieren verfügbar.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Zum Ersetzen des aktuellen Stundenplans kann nur ein einzelner Stundenplan ausgewählt werden.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Es gibt keinen aktuellen Stundenplan zum Ersetzen.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Dieses Stundenzeiten-Set wird noch von $count Stundenplan/Stundenplänen verwendet. Weisen Sie diese vor dem Löschen neu zu.';
  }

  @override
  String get weekdayMonday => 'Montag';

  @override
  String get weekdayTuesday => 'Dienstag';

  @override
  String get weekdayWednesday => 'Mittwoch';

  @override
  String get weekdayThursday => 'Donnerstag';

  @override
  String get weekdayFriday => 'Freitag';

  @override
  String get weekdaySaturday => 'Samstag';

  @override
  String get weekdaySunday => 'Sonntag';

  @override
  String get weekdayShortMonday => 'Mo';

  @override
  String get weekdayShortTuesday => 'Di';

  @override
  String get weekdayShortWednesday => 'Mi';

  @override
  String get weekdayShortThursday => 'Do';

  @override
  String get weekdayShortFriday => 'Fr';

  @override
  String get weekdayShortSaturday => 'Sa';

  @override
  String get weekdayShortSunday => 'So';

  @override
  String get monthJanuary => 'Jan';

  @override
  String get monthFebruary => 'Feb';

  @override
  String get monthMarch => 'Mär';

  @override
  String get monthApril => 'Apr';

  @override
  String get monthMay => 'Mai';

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
  String get monthDecember => 'Dez';

  @override
  String get semesterWeeksWholeTerm => 'Ganzes Semester';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Wochen $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Wochen $value';
  }

  @override
  String get generalSchedule => 'Terminplan';

  @override
  String get studentTimetable => 'Stundenplan';

  @override
  String get firstLaunchTitle => 'Startmodus auswählen';

  @override
  String get firstLaunchSubtitle =>
      'Wähle den Arbeitsbereich, den du am häufigsten nutzt. Du kannst den Modus später wechseln.';

  @override
  String get firstLaunchStudentDesc =>
      'Verwalte Stundenpläne, Kurse, Wochen, Unterrichtszeiten und Importe.';

  @override
  String get firstLaunchGeneralDesc =>
      'Verwalte Kategorien, Ereignisse, Erinnerungen und JSON- / ICS-Daten.';

  @override
  String get firstLaunchStartStudent => 'Mit Stundenplan starten';

  @override
  String get firstLaunchStartGeneral => 'Mit Terminplan starten';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Mit der Wahl eines Startarbeitsbereichs bestätigst du, dass du die ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Datenschutzrichtlinie';

  @override
  String get firstLaunchPrivacyConsentAfter =>
      ' gelesen hast und ihr zustimmst.';

  @override
  String get switchMode => 'Modus wechseln';

  @override
  String get generalScheduleComingSoon => 'Terminplanung bald verfügbar';

  @override
  String get switchToStudentTimetable => 'Zum Stundenplan wechseln';

  @override
  String get mySchedule => 'Mein Terminplan';

  @override
  String get today => 'Heute';

  @override
  String get addEvent => 'Termin hinzufügen';

  @override
  String get editEvent => 'Termin bearbeiten';

  @override
  String get eventTitle => 'Titel';

  @override
  String get eventTitleRequired => 'Geben Sie einen Titel ein';

  @override
  String get eventStartTime => 'Beginn';

  @override
  String get eventEndTime => 'Ende';

  @override
  String get eventDate => 'Datum';

  @override
  String get eventTime => 'Uhrzeit';

  @override
  String get eventNotes => 'Notizen';

  @override
  String get eventColor => 'Farbe';

  @override
  String get eventRecurrence => 'Wiederholung';

  @override
  String get recurrenceNone => 'Keine Wiederholung';

  @override
  String get recurrenceWeekly => 'Wöchentlich';

  @override
  String get recurrenceEndDate => 'Enddatum';

  @override
  String get recurrenceNoEndDate => 'Kein Enddatum';

  @override
  String get recurrenceSetEndDate => 'Festlegen';

  @override
  String get recurrenceChangeEndDate => 'Ändern';

  @override
  String get repeatsWeekly => 'Wiederholt sich wöchentlich';

  @override
  String recurrenceUntil(Object date) {
    return 'Bis $date';
  }

  @override
  String get switchToGeneralSchedule => 'Zum Terminplan wechseln';

  @override
  String get generalDisplaySettings => 'Allgemeine Anzeigeeinstellungen';

  @override
  String get generalDisplaySettingsDesc =>
      'Ansichten, Symbolleiste, Datumsformat und Schnellzugriff';

  @override
  String get closePopupOnOutsideTap => 'Popup durch Tippen außerhalb schließen';

  @override
  String get showGridLines => 'Gitterlinien anzeigen';

  @override
  String get generalScheduleImportExport =>
      'Kategorien importieren und exportieren';

  @override
  String get generalScheduleImportExportDesc =>
      'Kategorien des Terminplans importieren oder teilen';

  @override
  String get importGeneralSchedules => 'Kategorien importieren';

  @override
  String get importGeneralSchedulesDesc =>
      'Kategorien aus einer JSON-Datei lesen';

  @override
  String get shareGeneralSchedules => 'Kategorien teilen';

  @override
  String get shareGeneralSchedulesDesc => 'Kategorien als JSON-Datei teilen';

  @override
  String get saveGeneralSchedules => 'Kategorien speichern';

  @override
  String get saveGeneralSchedulesDesc => 'Kategorien als JSON-Datei speichern';

  @override
  String get selectSchedulesToExport => 'Zu exportierende Kategorien auswählen';

  @override
  String get selectSchedulesToImport => 'Zu importierende Kategorien auswählen';

  @override
  String generalScheduleEventCount(int count) {
    return 'Termine: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return '$count Kategorien importiert';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Den Import als neue Kategorie hinzufügen oder eine vorhandene Kategorie ersetzen?';

  @override
  String get addAsNewSchedule => 'Als neue Kategorie hinzufügen';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Wählen Sie mindestens eine Kategorie aus.';

  @override
  String get noExportableScheduleMessage =>
      'Keine Kategorie zum Exportieren vorhanden.';

  @override
  String get noSchedulesInImportMessage =>
      'Die Importdatei enthält keine Kategorien.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Wählen Sie genau eine importierte Kategorie zum Ersetzen aus.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Die zum Ersetzen ausgewählte Kategorie ist nicht verfügbar.';

  @override
  String get calendars => 'Kategorien';

  @override
  String get calendar => 'Kategorie';

  @override
  String get viewWeek => 'Woche';

  @override
  String get viewDay => 'Tag';

  @override
  String get viewList => 'Liste';

  @override
  String get viewMonth => 'Monat';

  @override
  String visibleCategoryCount(int count) {
    return '$count Kategorien';
  }

  @override
  String get noVisibleCategories => 'Keine sichtbaren Kategorien';

  @override
  String get selectCategoryToReplace => 'Zu ersetzende Kategorie auswählen';

  @override
  String get replaceCategory => 'Kategorie ersetzen';

  @override
  String get deleteEventTitle => 'Termin löschen';

  @override
  String get deleteEventConfirmation =>
      'Dieser Termin wird endgültig gelöscht.';

  @override
  String get deleteRecurringEventTitle => 'Wiederkehrenden Termin löschen';

  @override
  String get eventDuplicated => 'Termin dupliziert';

  @override
  String get searchEvents => 'Termine suchen';

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get filterByColor => 'Nach Farbe filtern';

  @override
  String get allColors => 'Alle Farben';

  @override
  String upcomingEventsCount(int count) {
    return 'Bevorstehend: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Überfällig: $count';
  }

  @override
  String get allDay => 'Ganztägig';

  @override
  String get collapseAllDayTimeline => 'Ganztägige Termine einklappen';

  @override
  String get expandAllDayTimeline => 'Ganztägige Termine ausklappen';

  @override
  String allDayEventsCount(int count) {
    return '$count ganztägige Termine';
  }

  @override
  String moreEvents(int count) {
    return '+$count weitere';
  }

  @override
  String get noMatchingEvents => 'Keine passenden Termine';

  @override
  String get noUpcomingEvents => 'Keine bevorstehenden Termine';

  @override
  String get addCalendar => 'Kategorie hinzufügen';

  @override
  String get newCalendar => 'Neue Kategorie';

  @override
  String get hideCalendar => 'Kategorie ausblenden';

  @override
  String get showCalendar => 'Kategorie anzeigen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get renameCalendar => 'Kategorie umbenennen';

  @override
  String get name => 'Name';

  @override
  String get deleteCalendar => 'Kategorie löschen';

  @override
  String deleteCalendarMessage(Object name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteThisOccurrence => 'Nur diesen Termin löschen';

  @override
  String get deleteFutureOccurrences => 'Diesen und folgende Termine löschen';

  @override
  String get deleteAllOccurrences => 'Gesamte Serie löschen';

  @override
  String get duplicateEvent => 'Duplizieren';

  @override
  String get repeatsDaily => 'Wiederholt sich täglich';

  @override
  String get repeatsMonthly => 'Wiederholt sich monatlich';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Wiederholt sich alle $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count-mal';
  }

  @override
  String get recurrenceDaily => 'Täglich';

  @override
  String get recurrenceMonthly => 'Monatlich';

  @override
  String get recurrenceCustom => 'Benutzerdefiniert';

  @override
  String get recurrenceEvery => 'Alle';

  @override
  String get recurrenceUnit => 'Einheit';

  @override
  String get recurrenceDays => 'Tage';

  @override
  String get recurrenceWeeks => 'Wochen';

  @override
  String get recurrenceMonths => 'Monate';

  @override
  String get recurrenceRepeatCount => 'Anzahl der Wiederholungen';

  @override
  String get recurrenceNoLimit => 'Unbegrenzt';

  @override
  String get recurrencePositiveNumber => 'Geben Sie eine positive Zahl ein';

  @override
  String get clearEndDate => 'Enddatum entfernen';

  @override
  String get pickDate => 'Datum auswählen';

  @override
  String get pickTime => 'Uhrzeit auswählen';

  @override
  String get reminder => 'Erinnerung in der App';

  @override
  String get reminderAtStart => 'Bei Beginn';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes Min. vorher';
  }

  @override
  String get reminderHourBefore => '1 Stunde vorher';

  @override
  String get reminderDayBefore => '1 Tag vorher';

  @override
  String get markReminderHandled => 'Als erledigt markieren';

  @override
  String get restoreReminder => 'App-Erinnerung wiederherstellen';

  @override
  String get reminderHandled => 'App-Erinnerung als erledigt markiert';

  @override
  String get reminderRestored => 'App-Erinnerung wiederhergestellt';

  @override
  String get reminderUpcoming => 'Bevorstehend';

  @override
  String get reminderOverdue => 'Überfällig';

  @override
  String get generalFitWeekColumnsToWidth =>
      'Wochenansicht an Bildschirm anpassen';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Die ganze Woche in kompakten Layouts anzeigen. Ausschalten für horizontales Scrollen. Eigene Zeiträume über 7 Tage bleiben scrollbar.';

  @override
  String get showWeekends => 'Wochenenden anzeigen';

  @override
  String get startHour => 'Anfangsstunde';

  @override
  String get endHour => 'Endstunde';

  @override
  String get timeGridDensity => 'Dichte des Zeitrasters';

  @override
  String get timeGridHourHeight => 'Höhe einer Stundenzeile';

  @override
  String get timeGridHourHeightHint =>
      'Passt die vertikale Skalierung der Tages- und Wochenansicht an, ohne das Rasterintervall von 15, 30 oder 60 Minuten zu ändern.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'JSON-Datei importieren';

  @override
  String get pasteJson => 'JSON einfügen';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Kategorien aus kopiertem JSON importieren';

  @override
  String get importIcsFile => 'ICS-Datei importieren';

  @override
  String get importIcsFileDesc => 'Termine aus einer .ics-Kalenderdatei lesen';

  @override
  String get pasteIcs => 'ICS einfügen';

  @override
  String get pasteIcsDesc => 'Termine aus kopiertem Kalendertext importieren';

  @override
  String get copyJson => 'JSON kopieren';

  @override
  String get copyJsonDesc => 'Ausgewählte Kategorien als JSON-Text kopieren';

  @override
  String get shareIcs => 'ICS teilen';

  @override
  String get shareIcsDesc => 'Ausgewählte Kalender als .ics teilen';

  @override
  String get saveIcs => 'ICS speichern';

  @override
  String get saveIcsDesc => 'Ausgewählte Kalender als .ics speichern';

  @override
  String get copyIcs => 'ICS kopieren';

  @override
  String get copyIcsDesc => 'Ausgewählte Kalender als ICS-Text kopieren';

  @override
  String get importIcs => 'ICS importieren';

  @override
  String get icsContent => 'ICS-Inhalt';

  @override
  String get pasteIcsContentHint =>
      'Hier den Inhalt ab BEGIN:VCALENDAR einfügen';

  @override
  String importIcsPreviewPrompt(int count) {
    return '$count Termine gefunden. Als neue Kategorie hinzufügen oder eine vorhandene Kategorie ersetzen?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return '$count Kategorien mit $warningCount Hinweisen importiert';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Ein Termin ohne Startzeit wurde übersprungen.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Ein Termin mit einer nicht unterstützten Startzeit wurde übersprungen.';

  @override
  String get importWarningAdjustedEnd =>
      'Die Endzeit eines Termins wurde korrigiert, da sie nicht nach dessen Startzeit lag.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Nicht unterstützte ICS-Felder wurden den Notizen hinzugefügt: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Nicht unterstütztes Wiederholungsintervall ignoriert: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Als ICS zu kopierende Kalender auswählen';

  @override
  String get selectCalendarsToExportIcs =>
      'Als ICS zu exportierende Kalender auswählen';

  @override
  String get exportIcsText => 'ICS-Text exportieren';

  @override
  String get exportJsonText => 'JSON-Text exportieren';

  @override
  String get dataRestoredFromBackupNotice =>
      'Die App-Daten wurden aus der vorherigen Sicherung wiederhergestellt, da die Hauptdatei nicht geladen werden konnte.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Sowohl die Hauptdatendatei als auch ihre Sicherung sind beschädigt. Die App verwendet jetzt einen neuen Datenbestand.';

  @override
  String get dataRecoveryCorruptTitle =>
      'Ihre Daten müssen wiederhergestellt werden';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked konnte weder die Hauptdatendatei noch deren Sicherung lesen. Vor dem Sperren weiterer Schreibzugriffe wurden geschützte Kopien erstellt.';

  @override
  String get dataRecoveryIoFailureTitle => 'Speicher nicht verfügbar';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked kann derzeit nicht auf den lokalen Speicher zugreifen. Prüfen Sie den Speicherzugriff und die Verfügbarkeit des Geräts und versuchen Sie es erneut. Vorhandene Daten werden nicht überschrieben.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Sked aktualisieren, um diese Daten zu öffnen';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Diese Daten wurden mit einer neueren Version von Sked erstellt. Aktualisieren Sie die App und versuchen Sie es dann erneut. Zum Schutz der Daten ist ein Neustart mit leeren Daten gesperrt.';

  @override
  String get dataRecoveryRetryAction => 'Erneut versuchen';

  @override
  String get dataRecoveryArtifactsHint =>
      'Wiederherstellungsdateien und betroffene Speicherorte sind unten aufgeführt. Verändern Sie diese Dateien nicht, bis Ihre Daten wiederhergestellt sind.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Wiederherstellungsdateien und Speicherorte anzeigen';

  @override
  String get dataRecoveryStartFreshAction => 'Mit neuen Daten beginnen';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Mit neuen Daten beginnen?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Die geschützten Kopien bleiben erhalten, aber Sked erstellt eine neue lokale Datendatei. Fahren Sie nur fort, wenn Sie die Wiederherstellung nicht zuerst erneut versuchen möchten.';

  @override
  String get previousMonth => 'Vorheriger Monat';

  @override
  String get nextMonth => 'Nächster Monat';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'Läuft';

  @override
  String get deleteCourseTitle => 'Kurs löschen';

  @override
  String get deleteCourseMessage => 'Diesen Kurs löschen?';

  @override
  String get showLunarCalendar => 'Mondkalender anzeigen';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count Termine';
  }

  @override
  String get defaultView => 'Standardansicht';

  @override
  String get generalDefaultViewSection => 'Beim Start';

  @override
  String get generalViewSwitchBehavior => 'Schaltfläche zum Ansichtswechsel';

  @override
  String get settingsWorkspaceMode => 'Aktiver Arbeitsbereich';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Arbeitsbereichsnavigation ausblenden';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Blende die Arbeitsbereichsnavigation aus. Wechseln ist weiterhin über das Arbeitsbereichsmenü der Hauptansicht möglich.';

  @override
  String get generalDateLabelFormat => 'Format der Datumsanzeige';

  @override
  String get generalDateLabelFormatLocalized => 'Lokalisiert (Juli 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Schrägstrich (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Anordnung der Symbolleiste';

  @override
  String get toolbarNavigationSection => 'Navigation in der Symbolleiste';

  @override
  String get toolbarNavigationHiddenBehavior => 'Ausgeblendete Elemente';

  @override
  String get toolbarNavigationRemove => 'Vollständig ausblenden';

  @override
  String get toolbarNavigationMore => 'In „Mehr“ verschieben';

  @override
  String get toolbarNavigationReorder => 'Elemente der Symbolleiste anordnen';

  @override
  String get toolbarNavigationVisibility =>
      'Element in der Symbolleiste anzeigen';

  @override
  String get toolbarNavigationTimetable => 'Stundenplanauswahl';

  @override
  String get toolbarNavigationWeek => 'Wochenauswahl';

  @override
  String get toolbarNavigationView => 'Ansichtswechsel';

  @override
  String get toolbarNavigationCategory => 'Kategorieauswahl';

  @override
  String get toolbarNavigationDate => 'Datumsauswahl';

  @override
  String get generalToolbarWidthPolicy => 'Platzverteilung der Symbolleiste';

  @override
  String get generalToolbarWidthContent => 'Automatische Verteilung';

  @override
  String get generalToolbarWidthBalanced => 'Ausgeglichen';

  @override
  String get generalToolbarWidthCalendarPriority => 'Kategorien bevorzugen';

  @override
  String get generalToolbarWidthDatePriority => 'Datum bevorzugen';

  @override
  String get generalViewSwitchCycle => 'Ansichten nacheinander wechseln';

  @override
  String get generalViewSwitchMenu => 'Ansichtsmenü öffnen';

  @override
  String get generalViewSwitchTooltip => 'Ansicht wechseln';

  @override
  String get generalViewSwitchMenuTooltip => 'Ansicht auswählen';

  @override
  String get generalViewLongPressTodayHint =>
      'Lange drücken, um zu heute zu wechseln';

  @override
  String get generalScheduleDisplaySection => 'Darstellung des Terminplans';

  @override
  String get generalTimeGridSection => 'Zeitraster';

  @override
  String get generalPopupSection => 'Popup-Verhalten';

  @override
  String get quickActionsSection => 'Schnellaktionen';

  @override
  String get showAddCourseFab =>
      'Schwebende Schaltfläche zum Hinzufügen von Kursen anzeigen';

  @override
  String get showAddCourseFabHint =>
      'Zeigt oder verbirgt die schwebende Schaltfläche zum Hinzufügen eines Kurses unten rechts im Stundenplan.';

  @override
  String get showAddEventFab =>
      'Schwebende Schaltfläche zum Hinzufügen von Terminen anzeigen';

  @override
  String get showAddEventFabHint =>
      'Zeigt oder verbirgt die schwebende Schaltfläche zum Hinzufügen eines Termins unten rechts im Terminplan.';

  @override
  String get enableLongPressAddCourse =>
      'Kurse durch langes Drücken auf ein leeres Feld hinzufügen';

  @override
  String get enableLongPressAddCourseHint =>
      'Drücken Sie lange auf einen leeren Bereich im Stundenplan, um einen Kurs hinzuzufügen.';

  @override
  String get enableLongPressAddEvent =>
      'Termine durch langes Drücken auf ein leeres Feld hinzufügen';

  @override
  String get enableLongPressAddEventHint =>
      'Drücken Sie in der Tages- oder Wochenansicht lange auf einen leeren Bereich im Zeitraster, um einen Termin hinzuzufügen.';

  @override
  String get developerModeTitle => 'Entwicklermodus';

  @override
  String get developerModeDescription =>
      'Werkzeuge zum Hinzufügen vollständiger Beispieldaten für die Prüfung von Darstellung und Interaktion.';

  @override
  String get developerSampleLanguage => 'Sprache der Beispieldaten';

  @override
  String get developerSampleChinese => 'Chinesisch';

  @override
  String get developerSampleEnglish => 'Englisch';

  @override
  String get developerSampleDataDescription =>
      'Fügt einen Stundenplan sowie Kategorien und Termine hinzu, ohne vorhandene Daten zu ersetzen.';

  @override
  String get developerAddSampleData => 'Beispieldaten hinzufügen';

  @override
  String get developerSampleDataAdded =>
      'Beispiel-Stundenplan und -Termine wurden hinzugefügt.';

  @override
  String get developerModeLongPressHint =>
      '3 Sekunden gedrückt halten, um den Entwicklermodus zu öffnen';

  @override
  String get developerNotificationDiagnostics => 'Benachrichtigungsdiagnose';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Prüfen Sie den Android-Zustellstatus, erstellen Sie den bestehenden Erinnerungsplan neu und senden Sie sichere Testbenachrichtigungen über den regulären Benachrichtigungsdienst von Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Die Benachrichtigungsdiagnose ist nur unter Android verfügbar.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Die Benachrichtigungsdiagnose ist erst verfügbar, nachdem die Terminkoordination gestartet wurde.';

  @override
  String get developerNotificationRefresh => 'Diagnose aktualisieren';

  @override
  String get developerNotificationSystemStatus =>
      'Berechtigung für Systembenachrichtigungen';

  @override
  String get developerNotificationPermissionAllowed => 'Erlaubt';

  @override
  String get developerNotificationPermissionBlocked => 'Gesperrt';

  @override
  String get developerNotificationExactAlarm => 'Exakte Alarme';

  @override
  String get developerNotificationExactAlarmAllowed => 'Erlaubt';

  @override
  String get developerNotificationExactAlarmBlocked => 'Nicht erlaubt';

  @override
  String get developerNotificationPlan => 'Benachrichtigungsplan für Termine';

  @override
  String get developerNotificationCoverage => 'Erinnerungsabdeckung';

  @override
  String get developerNotificationCoverageReady =>
      'Alle bekannten zeitlich begrenzten Erinnerungen sind direkt geplant';

  @override
  String get developerNotificationCoverageRenewable =>
      'Wiederkehrende Erinnerungen werden nach Möglichkeit langfristig weitergeplant';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Die Kapazität für direkte Alarme ist ausgeschöpft; spätere Erinnerungen werden nach Möglichkeit weitergeplant';

  @override
  String get developerNotificationCoverageBlocked =>
      'Die Voraussetzungen für eine genaue Zustellung sind nicht erfüllt';

  @override
  String get developerNotificationCoverageFailed =>
      'Die letzte Synchronisierung der Erinnerungen ist fehlgeschlagen';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled direkte Alarme / Kapazität: $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled eingeplant, $planned vorgesehen';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Letzter Fehler: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Benachrichtigungsplan neu erstellen';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Benachrichtigungsplan neu erstellt.';

  @override
  String get developerNotificationTestChannel => 'Testkanal';

  @override
  String get developerNotificationTestCourse => 'Kurserinnerungen';

  @override
  String get developerNotificationTestSchedule => 'Terminerinnerungen';

  @override
  String get developerNotificationImmediateTest => 'Sofortigen Test senden';

  @override
  String get developerNotificationThirtySecondTest =>
      'Hintergrundtest in 30 Sekunden planen';

  @override
  String get developerNotificationImmediateQueued =>
      'Sofortige Testbenachrichtigung gesendet.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Hintergrundtest in 30 Sekunden geplant.';

  @override
  String get developerNotificationAppSwitch => 'Erinnerungsschalter der App';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Reguläre Erinnerungen aktiviert';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Reguläre Erinnerungen deaktiviert; Entwicklertests sind weiterhin möglich';

  @override
  String get developerNotificationTimeZone => 'Lokale Zeitzone';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Noch nicht erstellt. Ein Entwicklertest erstellt den Kanal.';

  @override
  String get developerNotificationChannelEnabledState => 'Aktiviert';

  @override
  String get developerNotificationChannelBlockedState => 'Gesperrt';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Wichtigkeit: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Wichtigkeit nicht verfügbar';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending ausstehend / $active aktiv';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Zuletzt nativ angezeigt: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Noch kein Abgleich aufgezeichnet.';

  @override
  String get developerNotificationNextReminder => 'Nächste reguläre Erinnerung';

  @override
  String get developerNotificationNoPendingReminder =>
      'Keine zukünftige Erinnerung im aktuellen Plan';

  @override
  String get developerNotificationNextMaintenance => 'Nächste Wartung';

  @override
  String get developerNotificationNextRenewal =>
      'Nächste Weiterplanung nach Möglichkeit';

  @override
  String get developerNotificationNoMaintenance => 'Nicht geplant';

  @override
  String get developerNotificationTruncation => 'Begrenzung des Plans';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count durch die Plangrenze ausgelassen';
  }

  @override
  String get developerNotificationLastReconciliation => 'Letzter Abgleich';

  @override
  String get developerNotificationLastSynchronization =>
      'Letzte Erinnerungssynchronisierung';

  @override
  String get developerNotificationLateRecovery => 'Nachgeholte Erinnerungen';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count Erinnerung(en) wurden nach dem ursprünglichen Zeitpunkt nachgeholt';
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
  String get developerNotificationReconcileOriginForeground => 'Vordergrund';

  @override
  String get developerNotificationReconcileOriginBackground => 'Hintergrund';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Vollständiger Abgleich';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Wartung';

  @override
  String get developerNotificationReconcileModeRecovery => 'Wiederherstellung';

  @override
  String get developerNotificationRunRecovery =>
      'Erinnerungen wiederherstellen';

  @override
  String get developerNotificationRecoveryComplete =>
      'Wiederherstellung der Erinnerungen abgeschlossen';

  @override
  String get developerNotificationReconcileResultSuccess => 'Erfolgreich';

  @override
  String get developerNotificationReconcileResultSkipped => 'Übersprungen';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Gesperrt, bis alle Voraussetzungen für eine genaue Zustellung erfüllt sind';

  @override
  String get developerNotificationReconcileResultFailed => 'Fehlgeschlagen';

  @override
  String get developerNotificationBackgroundLimits =>
      'Hintergrundbeschränkungen des Herstellers';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Hintergrundbeschränkungen des Herstellers können die Zustellung beeinflussen.';

  @override
  String get developerNotificationAutostart =>
      'Hintergrundstart des Herstellers';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Hersteller: $vendor; ein Eintrag in den Herstellereinstellungen ist verfügbar. Android kann den Berechtigungsstatus nicht auslesen.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Hersteller: $vendor; stattdessen werden die App-Details geöffnet. Android kann den Berechtigungsstatus nicht auslesen.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Kein Eintrag für Hintergrundeinstellungen des Herstellers verfügbar.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Zuletzt geöffnetes Ziel: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'Herstellereinstellungen';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'App-Details';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'keines';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Grenzen der Wiederherstellung nach einem Neustart';

  @override
  String get developerNotificationRebootBoundary =>
      'Die Wiederherstellung beginnt erst nach dem ersten Entsperren. Eine zwangsweise beendete App kann sich nicht selbst starten.';

  @override
  String get developerNotificationTestChecking =>
      'Während der Benachrichtigungsstatus geprüft wird, sind keine Tests möglich.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Tests sind nicht möglich, da Systembenachrichtigungen gesperrt sind.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Tests sind nicht möglich, da der ausgewählte Benachrichtigungskanal gesperrt ist.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Über die Windows-Benachrichtigungseinstellungen verwaltet';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Unter Windows nicht anwendbar';

  @override
  String get developerNotificationWindowsIdentity => 'Windows-Paketidentität';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX-Identität verfügbar; angezeigte Benachrichtigungen können zurückgenommen werden';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Installieren Sie die MSIX-Version, um angezeigte Benachrichtigungen zuverlässig zurückzunehmen';

  @override
  String get collapseWorkspaceNavigation =>
      'Arbeitsbereichsnavigation einklappen';

  @override
  String get expandWorkspaceNavigation =>
      'Arbeitsbereichsnavigation ausklappen';

  @override
  String get schoolWebImportExitBrowser => 'Integrierten Browser schließen';

  @override
  String get schoolWebImportEditAddress => 'Adresse bearbeiten';

  @override
  String get schoolWebImportAddressLabel => 'Webadresse';

  @override
  String get schoolWebImportOpenAddress => 'Öffnen';

  @override
  String get schoolWebImportAddressInvalid =>
      'Gib eine HTTP- oder HTTPS-Adresse mit Host ein.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Diese Webseite hat ein neues Fenster angefordert, das auf diesem Gerät nicht geöffnet werden kann.';

  @override
  String get schoolWebImportSecureConnection => 'Sichere Verbindung';

  @override
  String get schoolWebImportInsecureConnection => 'Unsichere Verbindung';

  @override
  String get schoolWebImportSignInConsentTitle => 'Schulanmeldung öffnen?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Bei der Schulanmeldung können Anmeldedaten über Formulare oder Serverweiterleitungen an die Schule und deren Anmeldeanbieter gesendet werden. Android kann nicht jede solche Übertragung für eine separate Zielbestätigung anhalten. Fahren Sie nur fort, wenn Sie diesen Stellen für diese Importsitzung vertrauen:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Unsichere Schulanmeldung öffnen?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Diese Schulanmeldung verwendet HTTP. Jeder, der diese Verbindung beobachten oder verändern kann, kann Ihre Anmeldedaten und Seiteninhalte lesen oder ändern. Fahren Sie nur fort, wenn Sie dieses Risiko akzeptieren für:\n\n$origin';
  }

  @override
  String get notificationSettingsSection =>
      'Erinnerungen und Benachrichtigungen';

  @override
  String get notificationCoverage => 'Erinnerungsabdeckung';

  @override
  String get notificationCoverageRenewable =>
      'Wiederkehrende Termine ohne Enddatum werden im Hintergrund weitergeplant, damit Erinnerungen langfristig abgedeckt sind.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android kann bis zu $capacity Erinnerungen direkt einplanen. Spätere Erinnerungen werden im Voraus weitergeplant.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Erinnerungen und Benachrichtigungen aktivieren';

  @override
  String get notificationSettingsEnabledHint =>
      'Plant nur Einträge mit einer Erinnerung ein. Legen Sie unten eine Standarderinnerung für Kurse fest, die diese Einstellung übernehmen.';

  @override
  String get notificationPrecisionLimitations =>
      'Erinnerungen hängen von Systemberechtigungen und Hintergrundausführung ab. Ausschalten, Zeitänderungen oder Systembeschränkungen können sie verzögern.';

  @override
  String get notificationSettingsEnabledSummary => 'Aktiviert';

  @override
  String get notificationSettingsDisabledSummary => 'Deaktiviert';

  @override
  String get notificationDefaultsSection => 'Standarderinnerungen';

  @override
  String get notificationCourseDefaultReminder =>
      'Standarderinnerung für Kurse';

  @override
  String get notificationGeneralDefaultReminder =>
      'Standarderinnerung für Termine';

  @override
  String get notificationReminderOff => 'Keine Erinnerung';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes Minuten vorher';
  }

  @override
  String get notificationPermission => 'Benachrichtigungsberechtigung';

  @override
  String get notificationPermissionGranted => 'Vom System erlaubt';

  @override
  String get notificationPermissionDenied => 'Vom System gesperrt';

  @override
  String get notificationPermissionChecking => 'Berechtigung wird geprüft…';

  @override
  String get notificationPermissionRequest => 'Berechtigung anfordern';

  @override
  String get notificationPermissionOpenSettings => 'Systemeinstellungen öffnen';

  @override
  String get notificationPermissionRequestFailed =>
      'Die Benachrichtigungsberechtigung konnte nicht gelesen werden. Versuchen Sie es erneut.';

  @override
  String get notificationExactAlarm => 'Berechtigung für exakte Alarme';

  @override
  String get notificationExactAlarmAllowed => 'Vom System erlaubt';

  @override
  String get notificationExactAlarmRequired =>
      'Für genaue Erinnerungszeiten erforderlich';

  @override
  String get notificationExactAlarmRequest => 'Exakte Alarme erlauben';

  @override
  String get notificationBatteryOptimization => 'Akkuoptimierung';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Von der Android-Akkuoptimierung ausgenommen';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Für genaue Erinnerungen ist eine Ausnahme von der Android-Akkuoptimierung erforderlich';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Einstellungen zur Akkuoptimierung öffnen';

  @override
  String get notificationAutostart => 'Hintergrundstart des Herstellers';

  @override
  String get notificationAutostartVendorHint =>
      'Erlauben Sie den Autostart oder die Ausführung im Hintergrund, damit Erinnerungen nach einem Neustart wiederhergestellt werden können.';

  @override
  String get notificationAutostartFallbackHint =>
      'Öffnen Sie die App-Details von Sked und erlauben Sie die Ausführung im Hintergrund. Android kann diese Herstellereinstellung nicht prüfen.';

  @override
  String get notificationAutostartUnavailable =>
      'Es wurde keine Einstellungsseite des Herstellers gefunden. Prüfen Sie die App-Details von Sked manuell.';

  @override
  String get notificationAutostartRequest =>
      'Hintergrundeinstellungen des Herstellers öffnen';

  @override
  String get notificationAutostartOpenFailed =>
      'Die Hintergrundeinstellungen des Herstellers konnten nicht geöffnet werden. Prüfen Sie die App-Details von Sked manuell.';

  @override
  String get notificationLockScreenTitles =>
      'Titel auf dem Sperrbildschirm anzeigen';

  @override
  String get notificationLockScreenTitlesHint =>
      'Bei deaktivierter Option bleiben die Benachrichtigungsdetails auf dem Sperrbildschirm verborgen.';

  @override
  String get notificationWidgets => 'Startbildschirm-Widgets';

  @override
  String get notificationWidgetsDesc =>
      'Sked-Widgets aktualisieren und erfahren, wie Sie ein Widget über den Launcher hinzufügen.';

  @override
  String get notificationWidgetsDialogTitle => 'Sked-Widget hinzufügen';

  @override
  String get notificationWidgetsDialogMessage =>
      'Drücken Sie auf dem Startbildschirm Ihres Geräts lange auf einen leeren Bereich, wählen Sie „Widgets“ und fügen Sie ein Sked-Widget hinzu. Das Widget zeigt Ihre nächsten Kurse oder Termine.';

  @override
  String get notificationWidgetsRefresh => 'Widgets aktualisieren';

  @override
  String get notificationWidgetsRefreshed => 'Widgets aktualisiert';

  @override
  String get notificationPlatformUnsupported =>
      'Diese Plattform bietet keine nativen Benachrichtigungen.';

  @override
  String get workspaceFeatures => 'Funktionsverwaltung';

  @override
  String get workspaceBoth => 'Stundenplan und Termine';

  @override
  String get workspaceOnlyStudent => 'Nur Stundenplan';

  @override
  String get workspaceOnlyGeneral => 'Nur Termine';

  @override
  String get workspaceDisableTitle => 'Diesen Arbeitsbereich deaktivieren?';

  @override
  String get workspaceDisableMessage =>
      'Daten und Einstellungen bleiben erhalten. Funktionen und Erinnerungen werden angehalten, bis du den Bereich hier wieder aktivierst.';

  @override
  String get workspaceEnableHint =>
      'Wähle die benötigten Funktionen. Mindestens eine muss aktiv bleiben.';

  @override
  String get workspaceLastRequired =>
      'Mindestens ein Arbeitsbereich muss aktiv bleiben.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Der Arbeitsbereich ist deaktiviert, aber Erinnerungen konnten nicht entfernt werden. Versuche die Benachrichtigungswiederherstellung erneut.';

  @override
  String get settingsSearch => 'Einstellungen suchen';

  @override
  String get settingsNoResults => 'Keine passenden Einstellungen';

  @override
  String get settingsDataPrivacy => 'Daten und Datenschutz';

  @override
  String get workspacePreferences => 'Anzeige und Bedienung';

  @override
  String get workspaceManage => 'Verwalten';

  @override
  String get selectedDayAgenda => 'Ausgewählter Tag';

  @override
  String get notificationTroubleshooting => 'Berechtigungen und Fehlerbehebung';

  @override
  String get settingsConnection => 'Verbindung';

  @override
  String get settingsAdvanced => 'Erweitert';

  @override
  String get unsavedChangesMessage =>
      'Du hast ungespeicherte Änderungen. Verwerfen und verlassen?';

  @override
  String get backupWorkspaceSelection =>
      'Die vollständige Sicherung enthält Daten und die Auswahl aktiver Arbeitsbereiche.';

  @override
  String get assistantLayoutPreview => 'KI · Layoutvorschau';

  @override
  String get assistantSelectionContext =>
      'Verwendet die aktuelle Auswahl als Kontext';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Nachrichtenentwurf';

  @override
  String get assistantPreviewNoSend =>
      'Nur eine Layoutvorschau. Es wird nichts gesendet oder geändert.';

  @override
  String get resizePanel => 'Panelgröße ändern';

  @override
  String get minimizeWindow => 'Minimieren';

  @override
  String get maximizeWindow => 'Maximieren';

  @override
  String get restoreWindow => 'Fenster wiederherstellen';

  @override
  String get closeWindow => 'Fenster schließen';

  @override
  String get courseSystemReminder => 'Systemerinnerung';

  @override
  String courseReminderInherit(String reminder) {
    return 'Standard verwenden ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Systemerinnerungen sind in den Benachrichtigungseinstellungen deaktiviert. Diese Kurseinstellung kann trotzdem gespeichert werden.';

  @override
  String get courseReminderDefaultOff =>
      'Es ist keine Standarderinnerung für Kurse festgelegt. Wählen Sie hier eine eigene Erinnerung oder legen Sie einen Standard in den Benachrichtigungseinstellungen fest.';

  @override
  String get courseReminderDeliveryHint =>
      'Diese Einstellung wird mit dem Kurs gespeichert. Die Zustellung hängt von den Benachrichtigungsberechtigungen des Systems und den Hintergrundbeschränkungen ab.';

  @override
  String get courseReminderPermissionUnknown =>
      'Der Status der Systembenachrichtigungen wurde noch nicht geprüft. Prüfen Sie die Benachrichtigungseinstellungen, bevor Sie sich auf Erinnerungen verlassen.';

  @override
  String get courseReminderMinutesLabel => 'Minuten vor Kursbeginn';

  @override
  String get exportAction => 'Exportieren';

  @override
  String get datePickerSelectWeek => 'Woche auswählen';

  @override
  String get datePickerSelectMonth => 'Monat auswählen';

  @override
  String get generalDateLabelFormatDescription =>
      'Gilt für die Datumsnavigation auf Desktop- und kleineren Bildschirmen.';

  @override
  String get dateRangeTitle => 'Zeitraum auswählen';

  @override
  String get dateRangeCustom => 'Benutzerdefiniert';

  @override
  String get dateRangeChooseStart => 'Startdatum auswählen';

  @override
  String get dateRangeChooseEnd => 'Enddatum auswählen';

  @override
  String get dateRangeLimit =>
      'Wähle 1–14 Tage einschließlich Anfangs- und Enddatum.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return 'Benutzerdefiniert · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Mit Auswahlrädern wählen';

  @override
  String get courseReminderUseDefault => 'Standard verwenden';

  @override
  String get courseReminderInvalidMinutes =>
      'Geben Sie eine ganze Anzahl von Minuten ab null ein.';

  @override
  String get generalCustomColumnWidth =>
      'Spaltenbreite der benutzerdefinierten Ansicht';

  @override
  String get generalCustomColumnWidthAuto => 'Automatisch';

  @override
  String get generalCustomColumnWidthManual => 'Mindestbreite';

  @override
  String get generalCustomColumnWidthMinimum => 'Mindestbreite pro Tag';

  @override
  String get generalCustomColumnWidthHint =>
      'Für alle Tage gilt dieselbe Mindestbreite. Die Spalten füllen den verfügbaren Platz aus oder lassen sich seitlich scrollen. Dies betrifft nur die benutzerdefinierte Ansicht.';

  @override
  String get settingsAppearanceLanguage => 'Darstellung und Sprache';

  @override
  String get settingsAppearanceDetails => 'Farben und Umrisse';

  @override
  String get monthNoEvents => 'Keine Termine an diesem Tag';

  @override
  String get settingsOverview => 'Übersicht';

  @override
  String get settingsThemeTarget => 'Design für';

  @override
  String get settingsColorMode => 'Farbmodus';

  @override
  String get settingsNotificationPreferences => 'Erinnerungseinstellungen';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Standarderinnerungen, Berechtigungen und Zuverlässigkeit';

  @override
  String get settingsFeaturesSummary => 'Arbeitsbereiche und Navigation';

  @override
  String get settingsPrivacySummary =>
      'Datenschutzerklärung und lokale Daten löschen';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Unterrichtsstunden',
      one: '1 Unterrichtsstunde',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Unterrichtsstunde';

  @override
  String get periodTimesDurationColumn => 'Dauer';

  @override
  String get periodTimesGapColumn => 'Pause';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Warten auf das Speichern…';

  @override
  String get periodTimesSaveFailed =>
      'Nicht gespeichert · Speichern fehlgeschlagen';

  @override
  String get periodTimesInvalidStatus =>
      'Nicht gespeichert · Markierte Zeiten korrigieren';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked konnte nicht bestätigen, ob der letzte Speichervorgang rückgängig gemacht wurde. Schreibvorgänge sind angehalten und Wiederherstellungskopien bleiben erhalten. Prüfe den Speicher und versuche das Laden erneut.';

  @override
  String get settingsPanelDisplayMode => 'Paneldarstellung';

  @override
  String get settingsPanelDisplayModeGlobal => 'Für Stundenpläne und Kalender';

  @override
  String get settingsPanelDisplayOverlay => 'Überlagert';

  @override
  String get settingsPanelDisplaySideBySide => 'Nebeneinander';

  @override
  String get settingsPanelDisplayAutomatic => 'Automatisch';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Überlagert die rechte Seite, ohne die Kalenderbreite zu ändern.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Bevorzugt nebeneinander; überlagert nur, wenn der Kalender zu schmal würde.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Zeigt Panels nebeneinander bei ausreichend lesbarer Kalenderbreite, sonst überlagert.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Wenn Sie „Einstellungen“ oder „Arbeitsbereich“ in der Symbolleiste deaktivieren, wird der Eintrag nach „Mehr“ verschoben und nicht entfernt. „Mehr“ kann nicht ausgeblendet werden, solange es notwendige Aktionen enthält. Der Arbeitsbereichswechsel erscheint nur, wenn die untere Navigation ausgeblendet ist und mehrere Arbeitsbereiche aktiviert sind.';

  @override
  String get reminderEnded => 'Beendet';

  @override
  String get reminderAutoCloseHint =>
      'Schließt nach 10 Sekunden. Durch eine Interaktion bleibt es geöffnet.';

  @override
  String get showReminderIndependently => 'Separat öffnen';

  @override
  String get categoryManagerTitle => 'Kategorien verwalten';

  @override
  String get categoryHidden => 'Ausgeblendet';

  @override
  String get categoryShowOnCalendar => 'Im Kalender anzeigen';

  @override
  String get categoryHideOnCalendar => 'Im Kalender ausblenden';

  @override
  String get categoryEditColor => 'Kategoriefarbe ändern';

  @override
  String get categoryThemePalette => 'Designpalette';

  @override
  String get categoryCustomColor => 'Benutzerdefiniert';

  @override
  String get colorHexInvalid =>
      'Geben Sie einen sechsstelligen Hex-Farbwert ein.';

  @override
  String categoryColorSlot(int number) {
    return 'Designfarbe $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Updates im Store können später erscheinen. Maßgeblich ist die Verfügbarkeit auf der Store-Seite.';

  @override
  String get storePrereleaseNotice =>
      'Benachrichtigungen über Vorabversionen melden Sie nicht automatisch für einen Testkanal im Store an.';

  @override
  String get updateFoundTitle => 'Neue Version verfügbar';

  @override
  String get updateNoNotes =>
      'Es wurden keine Versionshinweise bereitgestellt.';

  @override
  String get updateLater => 'Später';

  @override
  String get updateRetry => 'Erneut versuchen';

  @override
  String get updatePrerelease => 'Vorabversion';

  @override
  String get updateNetworkFailure =>
      'Die Suche nach Updates ist nicht möglich. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Keine neuere Version gefunden (aktuell: $version)';
  }

  @override
  String get backupRestoreInProgressTitle =>
      'Sicherung wird wiederhergestellt…';

  @override
  String get backupRestoreInProgressMessage =>
      'Daten und Einstellungen können nach der Wiederherstellung geändert werden. Du kannst sie weiterhin ansehen.';
}
