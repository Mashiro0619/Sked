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
  String get timetableNameRequired => 'Timetable name is required';

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
  String get credits => 'Credits';

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
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'GitHub-Repository';

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
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

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
  String get schoolWebImportOpenPageHint =>
      'Melden Sie sich in der App auf der Schulwebsite an und navigieren Sie dann manuell zur Stundenplanseite.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

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
  String get schoolWebImportGoBack => 'Vorherige Seite';

  @override
  String get schoolWebImportLoadingPage => 'Seite wird geladen…';

  @override
  String get schoolWebImportParsing => 'Aktuelle Seite wird analysiert…';

  @override
  String get schoolWebImportLoadFailed =>
      'Seite konnte nicht geladen werden. Bitte aktualisieren Sie die Seite oder versuchen Sie es später erneut.';

  @override
  String get schoolWebImportLoadTimedOut =>
      'Zeitüberschreitung beim Laden der Seite. Bitte aktualisieren Sie die Seite und versuchen Sie es erneut.';

  @override
  String get schoolWebImportUnknownOrigin => 'Unbekannte Website';

  @override
  String get schoolWebImportCrossOriginTitle =>
      'Zu einer anderen Website wechseln?';

  @override
  String schoolWebImportCrossOriginMessage(Object origin) {
    return 'Für die Anmeldung beim Schulsystem muss möglicherweise eine andere Website geöffnet werden. Fahren Sie nur fort, wenn Sie diesem Ziel für die aktuelle Importsitzung vertrauen:\n\n$origin';
  }

  @override
  String get schoolWebImportEmptyPage =>
      'Der aktuelle Seiteninhalt ist leer und kann noch nicht importiert werden.';

  @override
  String get schoolWebImportSuccess => 'Web-Stundenplan importiert';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSettingsLocationHint =>
      'Configure it in Settings > Data & security > AI API configuration.';

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
  String get schoolImportParserBaseUrl => 'Base URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Die Base URL muss eine HTTP- oder HTTPS-Adresse mit Host sein.';

  @override
  String get schoolImportParserApiKey => 'API key';

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
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

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
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

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
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => 'Heute';

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
      'Ansichten, Symbolleiste, Datumsformat und Schnellzugriff';

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
  String get viewWeek => 'Woche';

  @override
  String get viewDay => 'Tag';

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
  String get collapseWorkspaceNavigation =>
      'Arbeitsbereichsnavigation einklappen';

  @override
  String get expandWorkspaceNavigation =>
      'Arbeitsbereichsnavigation ausklappen';
}
