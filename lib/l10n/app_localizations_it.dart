// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Settimana $week';
  }

  @override
  String get addCourse => 'Aggiungi corso';

  @override
  String get settings => 'Impostazioni';

  @override
  String get multiTimetableSwitch => 'Cambia orario';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Orario attuale · $weeks settimane';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Tocca per cambiare · $weeks settimane';
  }

  @override
  String get editTimetable => 'Modifica orario';

  @override
  String get schoolImportResultEditorTitle =>
      'Modifica il risultato analizzato';

  @override
  String get createTimetable => 'Nuovo orario';

  @override
  String get jumpToWeek => 'Vai alla settimana';

  @override
  String get timetable => 'Orario';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Nome dell\'orario';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Settimane totali';

  @override
  String get delete => 'Elimina';

  @override
  String get cancel => 'Annulla';

  @override
  String get save => 'Salva';

  @override
  String get deleteTimetableTitle => 'Elimina orario';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Nessun orario ancora';

  @override
  String get noTimetableMessage =>
      'Crea un orario o importane uno da un file JSON.';

  @override
  String get importTimetable => 'Importa orario';

  @override
  String get courseName => 'Nome del corso';

  @override
  String get location => 'Luogo';

  @override
  String get dayOfWeek => 'Giorno';

  @override
  String get semesterWeeks => 'Settimane';

  @override
  String get startTime => 'Ora di inizio';

  @override
  String get endTime => 'Ora di fine';

  @override
  String get linkedPeriods => 'Periodi collegati';

  @override
  String get linkedPeriodsUnmatched =>
      'Nessun periodo corrisponde all\'orario attuale. Tocca per scegliere manualmente.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Periodo $start-$end';
  }

  @override
  String get teacherName => 'Docente';

  @override
  String get credits => 'Crediti';

  @override
  String get remarks => 'Note';

  @override
  String get customFields => 'Campi personalizzati';

  @override
  String get customFieldsHint => 'Uno per riga, formato: chiave:valore';

  @override
  String get more => 'Altro';

  @override
  String get selectDayOfWeek => 'Scegli giorno';

  @override
  String get selectSemesterWeeks => 'Scegli settimane';

  @override
  String get selectAll => 'Seleziona tutto';

  @override
  String get clear => 'Cancella';

  @override
  String get confirm => 'Conferma';

  @override
  String get selectLinkedPeriods => 'Scegli periodi collegati';

  @override
  String get addCourseTitle => 'Aggiungi corso';

  @override
  String get editCourseTitle => 'Modifica corso';

  @override
  String get editCourseTooltip => 'Modifica corso';

  @override
  String get place => 'Luogo';

  @override
  String get time => 'Orario';

  @override
  String get notFilled => 'Non compilato';

  @override
  String get none => 'Nessuno';

  @override
  String get conflictCourses => 'Corsi in conflitto';

  @override
  String get locationNotFilled => 'Luogo non compilato';

  @override
  String get setAsDisplayed => 'Imposta come visualizzato';

  @override
  String get editThisCourse => 'Modifica questo corso';

  @override
  String get settingsTitle => 'Impostazioni';

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
      'Nessun orario è attualmente disponibile nelle impostazioni.';

  @override
  String get semesterStartDate => 'Data di inizio semestre';

  @override
  String get periodTimeSets => 'Set di orari dei periodi';

  @override
  String get noPeriodTimeAvailable =>
      'Nessun set di orari dei periodi disponibile';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count periodi';
  }

  @override
  String get coursePopupDismissSetting =>
      'Consenti tocco esterno per chiudere il popup del corso';

  @override
  String get coursePopupDismissSettingHint =>
      'Disattivandolo si disabilita anche la chiusura con scorrimento verso il basso.';

  @override
  String get preserveTimetableGaps => 'Mantieni gli spazi vuoti nell\'orario';

  @override
  String get preserveTimetableGapsHint =>
      'Se disattivato, le pause pranzo e gli intervalli vengono compressi e le lezioni successive si spostano verso l\'alto.';

  @override
  String get showPastEndedCourses => 'Mostra i corsi già terminati';

  @override
  String get showPastEndedCoursesHint =>
      'Mostra i corsi già conclusi rispetto alla settimana corrente reale con uno stile grigio più chiaro.';

  @override
  String get showFutureCourses => 'Mostra i corsi futuri';

  @override
  String get showFutureCoursesHint =>
      'Mostra con uno stile grigio i corsi non attivi questa settimana ma previsti nelle settimane successive.';

  @override
  String get timetableDisplaySettings =>
      'Visualizzazione e interazione dell\'orario';

  @override
  String get timetableDisplaySettingsDesc =>
      'Visualizzazione corsi, layout, gesti settimanali e aggiunta rapida';

  @override
  String get showTimetableGridLines =>
      'Mostra linee della griglia dell\'orario';

  @override
  String get showTimetableGridLinesHint =>
      'Controlla se le linee orizzontali e verticali della griglia sono visibili nell\'orario.';

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
  String get liveCourseOutlineColor => 'Colore del contorno del corso';

  @override
  String get liveCourseOutlineColorHint =>
      'Scegli se i contorni devono evidenziare il corso attuale/successivo oppure tutti i corsi mostrati nella pagina corrente.';

  @override
  String get liveCourseOutlineSettings => 'Contorno del corso';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Configura se il contorno è attivo, cosa evidenzia, se segue il colore del tema e il colore effettivo del contorno.';

  @override
  String get liveCourseOutlineEnabled => 'Abilita contorno';

  @override
  String get liveCourseOutlineFollowTheme => 'Segui il colore del tema';

  @override
  String get liveCourseOutlineTarget => 'Destinazione del contorno';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Corso attuale/successivo';

  @override
  String get liveCourseOutlineTargetAllDisplayed =>
      'Tutti i corsi visualizzati';

  @override
  String get liveCourseOutlineEffectiveColor => 'Colore effettivo';

  @override
  String get liveCourseOutlineCustomColor =>
      'Colore personalizzato del contorno';

  @override
  String get liveCourseOutlineWidth => 'Spessore del contorno';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Lingua';

  @override
  String get languagePageDescription =>
      'Scegli una delle lingue realmente disponibili nell\'app.';

  @override
  String get languageChinese => 'Cinese';

  @override
  String get languageEnglish => 'Inglese';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Risposta API';

  @override
  String get theme => 'Tema';

  @override
  String get themeFollowSystem => 'Segui il sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get themeColor => 'Colore del tema';

  @override
  String get themeColorModeSingle => 'Colore singolo del tema';

  @override
  String get themeColorModeColorful => 'Colorato';

  @override
  String get themeColorUiColors => 'Colori dell\'interfaccia';

  @override
  String get themeColorCourseColors => 'Colori dei corsi';

  @override
  String get themeColorPrimary => 'Primario';

  @override
  String get themeColorSecondary => 'Secondario';

  @override
  String get themeColorTertiary => 'Terziario';

  @override
  String get themeColorCourseText => 'Testo del corso';

  @override
  String get themeColorCourseTextAuto => 'Automatico';

  @override
  String get themeColorCourseTextCustom => 'Colore personalizzato';

  @override
  String get themeColorCourseColorsEmpty =>
      'I colori dei corsi verranno generati dopo l\'importazione di un orario.';

  @override
  String get themeCustomColor => 'Colore personalizzato';

  @override
  String get themeApplyCustomColor => 'Applica colore';

  @override
  String get themeApplySettings => 'Applica impostazioni';

  @override
  String get dataImportExport => 'Importa ed esporta dati';

  @override
  String get dataImportExportDesc =>
      'Importa tutti i dati o singoli orari, oppure esporta l\'orario corrente o tutti gli orari.';

  @override
  String get appBackupTitle => 'Backup e ripristino dell’app';

  @override
  String get appBackupSubtitle =>
      'Esegui il backup o ripristina orari, calendari, impostazioni e siti scolastici. Le chiavi API non sono incluse.';

  @override
  String get appBackupSheetSubtitle =>
      'Un ripristino completo sostituisce i dati attuali dell’app. Le chiavi API AI restano nell’archiviazione sicura e non vengono scritte nei file di backup.';

  @override
  String get restoreBackupFileTitle => 'Ripristina da file JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Scegli un file di backup completo di Sked. Dovrai confermare prima del ripristino.';

  @override
  String get restoreBackupTextTitle => 'Incolla JSON di backup';

  @override
  String get restoreBackupTextSubtitle =>
      'Incolla un backup completo e ripristina i dati attuali dell’app.';

  @override
  String get shareBackupTitle => 'Condividi file di backup';

  @override
  String get shareBackupSubtitle =>
      'Esporta tutti i dati dell’app come JSON. Le chiavi API sono escluse.';

  @override
  String get saveBackupTitle => 'Salva file di backup';

  @override
  String get saveBackupSubtitle =>
      'Salva un backup completo dell’app in un file locale.';

  @override
  String get copyBackupTitle => 'Copia testo di backup';

  @override
  String get copyBackupSubtitle =>
      'Mostra il JSON completo del backup per copiarlo o conservarlo temporaneamente.';

  @override
  String get restoreBackupConfirmTitle => 'Ripristinare il backup completo?';

  @override
  String get restoreBackupConfirmMessage =>
      'Questo sostituisce tutti gli orari, i calendari generali, le impostazioni e i siti scolastici attuali. Le chiavi API non vengono importate dai backup; reinserisci la chiave prima di analizzare di nuovo gli orari.';

  @override
  String get restoreBackupConfirmAction => 'Ripristina backup';

  @override
  String get restoreBackupSuccessMessage =>
      'Backup completo dell’app ripristinato. Le chiavi API AI devono essere reinserite.';

  @override
  String get restoreBackupFailureMessage =>
      'Ripristino non riuscito. Controlla il contenuto del backup e riprova.';

  @override
  String get openSourceLicenses => 'Licenze open source';

  @override
  String get openSourceLicensesDesc =>
      'Visualizza le licenze delle dipendenze Flutter e delle risorse dell\'icona dell\'app incluse.';

  @override
  String get checkForUpdates => 'Controlla aggiornamenti';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Hai già l\'ultima versione ($version)';
  }

  @override
  String get currentVersionLabel => 'Versione attuale';

  @override
  String get newVersionAvailable => 'Aggiornamento disponibile';

  @override
  String get latestVersionLabel => 'Ultima versione';

  @override
  String get updateContentLabel => 'Dettagli aggiornamento';

  @override
  String get officialWebsite => 'Sito ufficiale';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Cloud drive';

  @override
  String get ignoreThisVersion => 'Ignora questa versione';

  @override
  String get openUpdatesFailed => 'Impossibile aprire il link di aggiornamento';

  @override
  String get updateCheckFailedTitle => 'Controllo aggiornamenti non riuscito';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Repository GitHub';

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
      'Impossibile aprire il link del repository GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Impossibile aprire il link dell\'informativa sulla privacy';

  @override
  String get selectPeriodTimeSet => 'Scegli set di orari dei periodi';

  @override
  String get newItem => 'Nuovo';

  @override
  String get editPeriodTimeSet => 'Modifica set di orari dei periodi';

  @override
  String get importTimetableFiles => 'Importa orario';

  @override
  String get importTimetableFilesDesc => 'Supporta uno o più file di orario.';

  @override
  String get importTimetableText => 'Importa orario da testo';

  @override
  String get importTimetableTextDesc =>
      'Incolla il contenuto JSON dell\'orario e importalo.';

  @override
  String get shareTimetableFiles => 'Condividi file dell\'orario';

  @override
  String get shareTimetableFilesDesc => 'Scegli prima uno o più orari.';

  @override
  String get saveTimetableFiles => 'Salva file dell\'orario';

  @override
  String get saveTimetableFilesDesc => 'Scegli prima uno o più orari.';

  @override
  String get exportTimetableText => 'Esporta orario come testo';

  @override
  String get exportTimetableTextDesc =>
      'Scegli uno o più orari, poi copia il contenuto JSON.';

  @override
  String get jsonContent => 'Contenuto JSON';

  @override
  String get pasteJsonContentHint => 'Incolla il contenuto JSON da importare.';

  @override
  String get jsonContentEmpty => 'Incolla prima il contenuto JSON.';

  @override
  String get copyText => 'Copia';

  @override
  String get copiedToClipboard => 'Copiato negli appunti';

  @override
  String get share => 'Condividi';

  @override
  String get selectTimetablesToExport => 'Scegli gli orari da esportare';

  @override
  String get selectTimetablesToImport => 'Scegli gli orari da importare';

  @override
  String timetableCourseCount(int count) {
    return '$count corsi';
  }

  @override
  String get importAction => 'Importa';

  @override
  String get importTimetableDialogTitle => 'Importa orario';

  @override
  String get chooseImportMethod => 'Scegli come importare.';

  @override
  String get importAsNewTimetable => 'Importa come nuovo orario';

  @override
  String get replaceCurrentTimetable => 'Sostituisci l\'orario attuale';

  @override
  String get importPeriodTimeSetDialogTitle =>
      'Importa set di orari dei periodi';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Questo file contiene set di orari dei periodi inclusi. Vuoi importarli e associarli?';

  @override
  String get importBundledPeriodTimeSets => 'Importa e associa';

  @override
  String get discardBundledPeriodTimeSets => 'Scarta set inclusi';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Non è disponibile alcun set di orari dei periodi esistente, quindi quelli inclusi non possono essere scartati.';

  @override
  String savedToPath(Object path) {
    return 'Salvato in $path';
  }

  @override
  String get saveCancelled => 'Salvataggio annullato';

  @override
  String get fileSaveRestrictedTitle => 'Salvataggio file limitato';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Il sistema non è riuscito a salvare il file. Puoi riprovare o usare invece la condivisione.';

  @override
  String get retrySave => 'Riprova a salvare';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Abilita l\'accesso ai file nelle impostazioni di sistema, poi torna qui e prova di nuovo a esportare.';

  @override
  String get openSettings => 'Apri impostazioni';

  @override
  String get browserDownloadRestrictedTitle => 'Download del browser limitato';

  @override
  String get browserDownloadRestrictedMessage =>
      'Questo browser non supporta il salvataggio diretto in un file locale. Controlla i permessi di download del browser oppure usa la condivisione file.';

  @override
  String get switchToShare => 'Usa invece la condivisione';

  @override
  String get fileSaveFailedTitle => 'Salvataggio file non riuscito';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Impossibile scrivere nel percorso corrente. La cartella di destinazione potrebbe essere protetta, il file potrebbe essere in uso oppure il percorso potrebbe non essere scrivibile.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Il sistema non è riuscito a salvare il file. Puoi riprovare, controllare le impostazioni di sistema o usare invece la condivisione file.';

  @override
  String get retryLater => 'Riprova più tardi';

  @override
  String get exportSwitchedToShare =>
      'Esportazione passata alla condivisione file';

  @override
  String get saveFailedRetry => 'Salvataggio non riuscito. Riprova più tardi.';

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
  String get appInstanceBlockedTitle => 'Sked è già aperto';

  @override
  String get appInstanceBlockedMessage =>
      'Un\'altra finestra di Sked o un\'altra scheda del browser sta usando i tuoi dati locali. Chiudila, quindi riprova.';

  @override
  String get appInstanceLeaseFailedTitle =>
      'I dati locali non sono disponibili';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked non ha potuto verificare l\'accesso esclusivo ai dati locali. I tuoi dati non sono stati aperti né modificati. Controlla l\'accesso allo spazio di archiviazione, quindi riprova.';

  @override
  String get savingChanges => 'Salvataggio delle modifiche...';

  @override
  String get showApiKey => 'Mostra la chiave API';

  @override
  String get hideApiKey => 'Nascondi la chiave API';

  @override
  String get importFailedCheckContent =>
      'Importazione non riuscita. Controlla il contenuto del file.';

  @override
  String get noImportableTimetables =>
      'Nessun orario utilizzabile trovato nel file importato.';

  @override
  String importedTimetablesCount(int count) {
    return 'Importati $count orari';
  }

  @override
  String get periodTimesTitle => 'Orari dei periodi';

  @override
  String get importExport => 'Importa ed esporta';

  @override
  String get importPeriodTemplate => 'Importa modello dei periodi';

  @override
  String get importPeriodTemplateText => 'Importa modello dei periodi da testo';

  @override
  String get sharePeriodTemplate => 'Condividi modello dei periodi';

  @override
  String get saveTemplateToFile => 'Salva modello su file';

  @override
  String get exportPeriodTemplateText =>
      'Esporta modello dei periodi come testo';

  @override
  String get deletePeriodTimeSet => 'Elimina set di orari dei periodi';

  @override
  String get periodTimeSetName => 'Nome del set di orari dei periodi';

  @override
  String get addOnePeriod => 'Aggiungi periodo';

  @override
  String periodNumberLabel(int index) {
    return 'Periodo $index';
  }

  @override
  String get deleteThisPeriod => 'Elimina questo periodo';

  @override
  String durationMinutes(int minutes) {
    return 'Durata $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Intervallo dal precedente $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'L\'ora di fine deve essere successiva all\'ora di inizio';

  @override
  String get periodOverlapPrevious =>
      'Questo periodo si sovrappone al precedente';

  @override
  String get periodTimesSaved => 'Orari dei periodi salvati';

  @override
  String get deletePeriodTimeSetTitle => 'Elimina set di orari dei periodi';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'set di orari dei periodi attuale';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Importati $count orari dei periodi';
  }

  @override
  String get periodFilePermissionTitle => 'Permesso file necessario';

  @override
  String get androidFilePermissionMessage =>
      'L\'esportazione su Android richiede il permesso di accesso ai file. Concedilo per continuare a salvare.';

  @override
  String get reauthorize => 'Autorizza di nuovo';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Permesso negato in modo permanente';

  @override
  String get permissionSettingsExportMessage =>
      'Abilita l\'accesso ai file nelle impostazioni di sistema, poi torna qui e prova di nuovo a esportare.';

  @override
  String get privacyPolicyTitle => 'Informativa sulla privacy';

  @override
  String get privacyPolicyEntryDesc =>
      'Scopri come l\'app gestisce archiviazione locale, configurazione dei siti scolastici, importazione/esportazione file, parsing delle pagine web e link esterni.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Versione accettata: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked è uno strumento di orari che privilegia l\'archiviazione locale. Orari, set di periodi e configurazione dei siti scolastici sono memorizzati solo sul tuo dispositivo o nel browser e non vengono mai caricati automaticamente. L\'app elabora i dati solo quando attivi esplicitamente azioni come importazione, parsing di pagine web, condivisione o apertura di link esterni. L\'informativa completa sulla privacy è disponibile online.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Archiviazione locale';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Importazione ed esportazione';

  @override
  String get privacyPolicyImportExportBody =>
      'L\'app legge o scrive file JSON dell\'orario, file JSON dei siti scolastici e file modello dei periodi solo quando scegli esplicitamente un file o avvii un\'esportazione. L\'importazione di questi file è un\'operazione locale, a meno che tu non scelga anche il parsing della pagina web. Anche il recupero di un elenco di modelli personalizzati è un\'azione di rete esplicita e contatta solo l\'endpoint personalizzato che hai configurato.';

  @override
  String get privacyPolicySharingTitle => 'Condivisione';

  @override
  String get privacyPolicySharingBody =>
      'Quando usi esplicitamente la condivisione, l\'app passa il file esportato al pannello di condivisione del sistema o all\'app di destinazione che scegli. Il modo in cui quel file viene poi gestito dipende dall\'app o dal servizio di destinazione selezionato.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Link esterni';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Quando apri link esterni come il repository GitHub, l\'app delega l\'azione al browser o a un\'altra applicazione esterna. La gestione dei dati da quel momento in poi è regolata dalla terza parte che apri.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Cosa non raccoglie l\'app';

  @override
  String get privacyPolicyNoCollectionBody =>
      'L\'app non richiede un account Sked e non abilita analytics, identificatori pubblicitari o backup cloud. Inoltre non fornisce un campo dedicato alla raccolta delle password degli account scolastici. Se accedi a un sito scolastico all\'interno dell\'app, quell\'interazione avviene nella pagina scolastica che hai aperto.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Parsing delle pagine web';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Quando usi l’importazione da una pagina web scolastica o analizzi testo di orario / HTML incollato, l’app prima prepara e pulisce il contenuto localmente, poi invia il testo dell’orario, il testo della pagina o il contenuto HTML inviato, il titolo e l’URL opzionali della pagina, la lingua corrente dell’app e il contenuto del prompt del parser all’endpoint compatibile con OpenAI che hai configurato. Anche il recupero dell’elenco dei modelli richiede lo stesso endpoint. Sked non fornisce un endpoint di parsing integrato e non invia richieste di parsing a un backend di analisi degli orari controllato dallo sviluppatore. L’endpoint personalizzato e gli eventuali servizi upstream possono salvare, inoltrare, limitare, eliminare o trattare altrimenti i dati secondo le regole del provider di servizi scelto. Se usi una Base URL http://, usala solo su dispositivi, reti e servizi endpoint attendibili, perché contenuti e chiavi API potrebbero non essere protetti dalla crittografia di trasporto.';

  @override
  String get privacyPolicyUpdatesTitle => 'Aggiornamenti dell\'informativa';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'La versione attuale dell\'informativa sulla privacy è $version. Se una versione successiva modifica il modo in cui vengono gestiti i dati, l\'app potrebbe chiederti di leggere e accettare nuovamente l\'informativa aggiornata.';
  }

  @override
  String get privacyGateTitle =>
      'Accetta l\'informativa sulla privacy prima di usare l\'app';

  @override
  String get privacyGateSummaryStorage =>
      'Orari, set di orari dei periodi e configurazione dei siti scolastici sono memorizzati solo localmente e non vengono caricati automaticamente su un server dello sviluppatore.';

  @override
  String get privacyGateSummaryImportExport =>
      'Importazione, esportazione e condivisione avvengono solo quando le avvii esplicitamente; il parsing delle pagine web invia solo il contenuto compresso che hai inviato al tuo endpoint di parsing configurato e puoi controllare l\'orario analizzato prima di salvarlo.';

  @override
  String get privacyGateSummaryUpdates =>
      'Se una versione successiva cambia il modo in cui vengono gestiti i dati, l\'app potrebbe chiederti di rivedere di nuovo l\'informativa aggiornata.';

  @override
  String get schoolWebImportEntry => 'Importa dalla pagina web della scuola';

  @override
  String get schoolWebImportEntryDesc =>
      'Importa la pagina dell\'orario corrente dal sito della scuola.';

  @override
  String get schoolSitesManageEntry => 'Gestisci siti scolastici';

  @override
  String get schoolSitesManageEntryDesc =>
      'Aggiungi, modifica ed elimina URL di accesso scolastici, con importazione ed esportazione JSON.';

  @override
  String get schoolSitesPageTitle => 'Gestione siti scolastici';

  @override
  String get schoolSitesImportJson => 'Importa JSON scolastico';

  @override
  String get schoolSitesShareJson => 'Condividi JSON scolastico';

  @override
  String get schoolSitesSaveJson => 'Salva JSON scolastico';

  @override
  String get schoolSitesSaved => 'Siti scolastici salvati';

  @override
  String get schoolSitesImported => 'Siti scolastici importati';

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
      'Nessuna configurazione di sito scolastico ancora.';

  @override
  String get schoolSitesNameLabel => 'Nome della scuola';

  @override
  String get schoolSitesLoginUrlLabel => 'URL di accesso';

  @override
  String get schoolSitesAdd => 'Aggiungi scuola';

  @override
  String get schoolSitesEdit => 'Modifica scuola';

  @override
  String get schoolSitesDeleteTitle => 'Elimina scuola';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Compila prima il nome della scuola e l\'URL di accesso.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Importa incollando il contenuto della pagina dell\'orario';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Incolla manualmente il codice sorgente o il contenuto grezzo della pagina che contiene le informazioni dell\'orario.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Analizza orario dal contenuto della pagina';

  @override
  String get schoolHtmlImportUrlLabel => 'URL sorgente (opzionale)';

  @override
  String get schoolHtmlImportTitleLabel => 'Titolo della pagina (opzionale)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Contenuto della pagina';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Incolla qui il codice sorgente o il contenuto grezzo della pagina che contiene informazioni sull\'orario.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Può essere analizzato e importato qualsiasi contenuto che contenga informazioni sull\'orario, non solo HTML.';

  @override
  String get schoolHtmlImportCompress => 'Prepara contenuto';

  @override
  String get schoolHtmlImportCompressed => 'Contenuto preparato';

  @override
  String get schoolHtmlImportCompressFirst => 'Prepara prima il contenuto.';

  @override
  String get schoolHtmlImportSubmit => 'Analizza e importa';

  @override
  String get schoolImportContentTruncated =>
      'Questa pagina ha raggiunto il limite di importazione sicura. Solo la parte acquisita verrà inviata per l’analisi.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'L\'analisi potrebbe richiedere un po\' di tempo. Attendi.';

  @override
  String get schoolHtmlImportEmpty => 'Incolla prima l\'HTML della pagina.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Torna alla pagina web';

  @override
  String get schoolWebImportPageTitle =>
      'Importazione da pagina web scolastica';

  @override
  String get schoolWebImportPreview => 'Anteprima importazione';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count corsi';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count periodi';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Titolo della pagina';

  @override
  String get schoolWebImportParserUsed => 'Parser';

  @override
  String get schoolWebImportWarnings => 'Note di importazione';

  @override
  String get schoolWebImportParserDetails => 'Dettagli dell\'analisi';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Espandi i dettagli dell\'analisi';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Comprimi i dettagli dell\'analisi';

  @override
  String get schoolWebImportOpenPageHint =>
      'Accedi al sito della scuola nell\'app, poi vai manualmente alla pagina dell\'orario.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Questa piattaforma non supporta ancora il login web incorporato. Usa una piattaforma con supporto WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Scegli scuola';

  @override
  String get schoolWebImportNoSchools =>
      'Nessuna configurazione scolastica disponibile. Controlla prima school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Impossibile caricare la configurazione scolastica. Controlla il formato del file JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importa pagina corrente';

  @override
  String get schoolWebImportLoadingPage => 'Caricamento pagina…';

  @override
  String get schoolWebImportParsing => 'Analisi della pagina corrente…';

  @override
  String get schoolWebImportLoadFailed =>
      'Caricamento della pagina non riuscito. Aggiorna o riprova più tardi.';

  @override
  String get schoolWebImportUnknownOrigin => 'Sito sconosciuto';

  @override
  String get schoolWebImportExitTitle => 'Uscire dal browser?';

  @override
  String get schoolWebImportExitMessage =>
      'La pagina verrà chiusa. Tutto ciò che non hai ancora importato andrà perso.';

  @override
  String get schoolWebImportExitConfirm => 'Esci';

  @override
  String get schoolWebImportEmptyPage =>
      'Il contenuto della pagina corrente è vuoto e non può ancora essere importato.';

  @override
  String get schoolWebImportSuccess => 'Orario web importato';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Sorgente del parser';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'OpenAI-compatibile personalizzato';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Parser OpenAI-compatibile personalizzato';

  @override
  String get schoolImportParserCustomPromptTitle => 'Prompt personalizzato';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Modifica qui il prompt integrato del parser. Le modifiche influenzano solo il parser OpenAI-compatibile personalizzato.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Il prompt integrato viene caricato qui per impostazione predefinita. Cancellalo per tornare alla versione integrata.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Ripristina prompt predefinito';

  @override
  String get schoolImportParserBaseUrl => 'URL di base';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'La Base URL deve essere un URL HTTP o HTTPS con host.';

  @override
  String get schoolImportParserApiKey => 'Chiave API';

  @override
  String get schoolImportParserModel => 'Modello';

  @override
  String get schoolImportParserFetchModels => 'Recupera elenco modelli';

  @override
  String get schoolImportParserFetchingModels => 'Recupero modelli...';

  @override
  String get schoolImportParserNoModelsFound =>
      'Nessun modello restituito dall\'endpoint.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Impossibile recuperare i modelli. Controlla l\'endpoint e riprova.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Recuperati $count modelli';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Usare un endpoint HTTP non crittografato?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'La chiave API e il contenuto dell’orario potrebbero essere letti o modificati durante il trasferimento. Continua solo se ritieni attendibili questo dispositivo, la rete e l’endpoint. L’autorizzazione resta valida finché non chiudi Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'La configurazione del parser personalizzato è incompleta. Inserisci prima URL di base, chiave API e modello.';

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
    return 'Parser: personalizzato ($model)';
  }

  @override
  String get privacyViewFullPolicy =>
      'Visualizza informativa completa sulla privacy';

  @override
  String get privacyAgreeAndContinue => 'Accetta e continua';

  @override
  String get privacyDecline => 'Rifiuta';

  @override
  String get privacyDeclineWebHint =>
      'Questo ambiente browser non consente all\'app di chiudere la pagina al posto tuo. Se non accetti, chiudi tu stesso questa scheda o finestra.';

  @override
  String get defaultPeriodTimeSetName => 'Periodi predefiniti';

  @override
  String get periodTimeSetFallbackName => 'Orari dei periodi';

  @override
  String get untitledTimetableName => 'Orario senza titolo';

  @override
  String get newTimetableName => 'Nuovo orario';

  @override
  String get newPeriodTimeSetName => 'Nuovo set di orari dei periodi';

  @override
  String get emptyTimetableName => 'Orario vuoto';

  @override
  String importedPeriodTimeSetName(Object name) {
    return 'Periodi di $name';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Il tipo di file importato non corrisponde.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Questa versione del file di importazione non è ancora supportata.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Nessun orario dei periodi trovato nel file importato.';

  @override
  String get selectAtLeastOneTimetableMessage => 'Seleziona almeno un orario.';

  @override
  String get noExportableTimetableMessage =>
      'Non c\'è alcun orario disponibile da esportare.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'La sostituzione dell\'orario attuale supporta solo la selezione di un singolo orario.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Non c\'è alcun orario attuale da sostituire.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Questo set di orari dei periodi è ancora usato da $count orario/i. Riassegnali prima di eliminarlo.';
  }

  @override
  String get weekdayMonday => 'Lunedì';

  @override
  String get weekdayTuesday => 'Martedì';

  @override
  String get weekdayWednesday => 'Mercoledì';

  @override
  String get weekdayThursday => 'Giovedì';

  @override
  String get weekdayFriday => 'Venerdì';

  @override
  String get weekdaySaturday => 'Sabato';

  @override
  String get weekdaySunday => 'Domenica';

  @override
  String get weekdayShortMonday => 'Lun';

  @override
  String get weekdayShortTuesday => 'Mar';

  @override
  String get weekdayShortWednesday => 'Mer';

  @override
  String get weekdayShortThursday => 'Gio';

  @override
  String get weekdayShortFriday => 'Ven';

  @override
  String get weekdayShortSaturday => 'Sab';

  @override
  String get weekdayShortSunday => 'Dom';

  @override
  String get monthJanuary => 'Gen';

  @override
  String get monthFebruary => 'Feb';

  @override
  String get monthMarch => 'Mar';

  @override
  String get monthApril => 'Apr';

  @override
  String get monthMay => 'Mag';

  @override
  String get monthJune => 'Giu';

  @override
  String get monthJuly => 'Lug';

  @override
  String get monthAugust => 'Ago';

  @override
  String get monthSeptember => 'Set';

  @override
  String get monthOctober => 'Ott';

  @override
  String get monthNovember => 'Nov';

  @override
  String get monthDecember => 'Dic';

  @override
  String get semesterWeeksWholeTerm => 'Tutto il semestre';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Settimane $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Settimane $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Scegli la modalità iniziale';

  @override
  String get firstLaunchSubtitle =>
      'Scegli lo spazio di lavoro che usi di più. Potrai cambiare modalità in seguito.';

  @override
  String get firstLaunchStudentDesc =>
      'Gestisci orari, corsi, settimane, ore delle lezioni e importazioni.';

  @override
  String get firstLaunchGeneralDesc =>
      'Gestisci categorie, eventi, promemoria e dati JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Inizia con l’orario';

  @override
  String get firstLaunchStartGeneral => 'Inizia con il calendario';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Scegliendo uno spazio di lavoro iniziale, confermi di aver letto e accettato l\'';

  @override
  String get firstLaunchPrivacyConsentLink => 'Informativa sulla privacy';

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
  String get today => 'Oggi';

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
      'Viste, barra degli strumenti, formato data e aggiunta rapida';

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
  String get viewWeek => 'Settimana';

  @override
  String get viewDay => 'Giorno';

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
  String get developerModeTitle => 'Modalità sviluppatore';

  @override
  String get developerModeDescription =>
      'Strumenti per aggiungere dati di esempio completi e verificare aspetto e interazioni.';

  @override
  String get developerSampleLanguage => 'Lingua dei dati di esempio';

  @override
  String get developerSampleChinese => 'Cinese';

  @override
  String get developerSampleEnglish => 'Inglese';

  @override
  String get developerSampleDataDescription =>
      'Aggiunge un orario e un insieme di categorie ed eventi senza sostituire i dati esistenti.';

  @override
  String get developerAddSampleData => 'Aggiungi dati di esempio';

  @override
  String get developerSampleDataAdded =>
      'Orario ed eventi di esempio aggiunti.';

  @override
  String get developerModeLongPressHint =>
      'Tieni premuto per 3 secondi per aprire la modalità sviluppatore';

  @override
  String get collapseWorkspaceNavigation =>
      'Comprimi navigazione area di lavoro';

  @override
  String get expandWorkspaceNavigation => 'Espandi navigazione area di lavoro';

  @override
  String get schoolWebImportExitBrowser => 'Esci dal browser integrato';

  @override
  String get schoolWebImportEditAddress => 'Modifica indirizzo';

  @override
  String get schoolWebImportAddressLabel => 'Indirizzo web';

  @override
  String get schoolWebImportOpenAddress => 'Apri';

  @override
  String get schoolWebImportAddressInvalid =>
      'Inserisci un indirizzo HTTP o HTTPS con un host.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Questa pagina web ha richiesto una nuova finestra che non può essere aperta su questo dispositivo.';

  @override
  String get schoolWebImportSecureConnection => 'Connessione sicura';

  @override
  String get schoolWebImportInsecureConnection => 'Connessione non sicura';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Aprire l’accesso al sistema scolastico?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'L’accesso al sistema scolastico può inviare credenziali tramite moduli o reindirizzamenti del server alla scuola e ai relativi provider di accesso. Android non può sospendere ogni trasferimento di questo tipo per mostrare una conferma separata della destinazione. Continua solo se li ritieni attendibili per questa sessione di importazione:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Aprire un accesso scolastico non sicuro?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Questo accesso scolastico usa HTTP. Chiunque possa osservare o alterare la connessione potrebbe leggere o modificare le credenziali e il contenuto della pagina. Continua solo se accetti questo rischio per:\n\n$origin';
  }
}
