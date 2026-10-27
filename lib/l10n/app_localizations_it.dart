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
  String get schoolImportParsePageTitle => 'Analizza orario';

  @override
  String get schoolImportParsePageParsing => 'Analisi in corso…';

  @override
  String get schoolImportParsePageFailed => 'Analisi non riuscita';

  @override
  String get schoolImportParseErrorMessage =>
      'Impossibile analizzare l’orario. Controlla il contenuto, le impostazioni del parser e la connessione di rete, poi riprova.';

  @override
  String get schoolImportParsePageContinue => 'Continua';

  @override
  String get schoolImportExpandWarnings => 'Mostra gli avvisi di importazione';

  @override
  String get schoolImportCollapseWarnings =>
      'Nascondi gli avvisi di importazione';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Alcuni corsi proseguono fino alla settimana $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Sostituire l’orario attuale?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'L’orario importato sostituirà quello attuale.';

  @override
  String get createTimetable => 'Nuovo orario';

  @override
  String get jumpToWeek => 'Vai alla settimana';

  @override
  String get timetable => 'Orario';

  @override
  String get themeWorkspaceSchedule => 'Agenda';

  @override
  String get timetableName => 'Nome dell\'orario';

  @override
  String get timetableNameRequired => 'Inserisci il nome dell’orario';

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
  String get customFieldsInvalidJson =>
      'Inserisci un oggetto JSON valido oppure svuota il campo.';

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
  String get settingsSectionAppearance => 'Aspetto';

  @override
  String get settingsSectionWorkspace => 'Area di lavoro';

  @override
  String get settingsSectionAbout => 'Informazioni su Sked';

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
  String get timetableHorizontalLayoutSection =>
      'Disposizione orizzontale e gesti';

  @override
  String get fitDaySelectorToWidth =>
      'Adatta il selettore dei giorni allo schermo';

  @override
  String get fitDaySelectorToWidthHint =>
      'Mostra tutti e sette i giorni sullo schermo quando possibile. Disattiva questa opzione per usare una larghezza fissa e scorrere.';

  @override
  String get fitWeekColumnsToWidth =>
      'Adatta le colonne settimanali allo schermo';

  @override
  String get enableWeekSwipeNavigation => 'Scorri per cambiare settimana';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Scorri a sinistra o a destra per cambiare settimana. Con larghezze fisse, trascina prima oltre il bordo.';

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
  String get includePrereleaseUpdates => 'Ricevi aggiornamenti preliminari';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Includi le versioni Alpha, Beta e RC, che potrebbero essere instabili. Se disattivato, vengono proposte solo versioni stabili.';

  @override
  String get currentVersionLabel => 'Versione attuale';

  @override
  String get newVersionAvailable => 'Aggiornamento disponibile';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get ignoreThisVersion => 'Ignora questa versione';

  @override
  String get openUpdatesFailed => 'Impossibile aprire il link di aggiornamento';

  @override
  String get updateCheckFailedTitle => 'Controllo aggiornamenti non riuscito';

  @override
  String get githubRepository => 'Repository GitHub';

  @override
  String get googlePlayStoreDesc => 'Visualizza Sked su Google Play';

  @override
  String get openGooglePlayFailed => 'Impossibile aprire Google Play';

  @override
  String get microsoftStoreDesc => 'Visualizza Sked nel Microsoft Store';

  @override
  String get openMicrosoftStoreFailed => 'Impossibile aprire Microsoft Store';

  @override
  String get starSkedOnGithub => 'Aggiungi una stella a Sked su GitHub!';

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
  String get studentDayEmpty => 'Nessuna lezione per questo giorno';

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
  String get periodTimesUnsavedExitTitle => 'Modifiche non salvate';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Impossibile salvare le ultime modifiche agli orari dei periodi. Puoi riprovare, continuare a modificarli o scartare le modifiche.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Alcuni orari dei periodi non sono validi. Correggili prima di salvare oppure scarta le modifiche ed esci.';

  @override
  String get discardChangesAndExit => 'Scarta ed esci';

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
      'Sked è uno strumento per gli orari delle lezioni che privilegia l’archiviazione locale. Gli orari delle lezioni, le agende generali, i gruppi di orari delle lezioni e la configurazione dei siti scolastici sono memorizzati solo sul dispositivo o nel browser e non vengono mai caricati automaticamente. L’app elabora i dati solo quando avvii esplicitamente azioni come l’importazione, l’analisi di testo / HTML dell’orario, l’importazione di pagine web scolastiche, la condivisione o l’apertura di link esterni. L’informativa sulla privacy completa è disponibile online.';

  @override
  String get privacyGateTitle =>
      'Accetta l\'informativa sulla privacy prima di usare l\'app';

  @override
  String get privacyGateSummaryStorage =>
      'Gli orari delle lezioni, le agende generali, i gruppi di orari delle lezioni e la configurazione dei siti scolastici sono memorizzati solo localmente e non vengono caricati automaticamente su un server dello sviluppatore.';

  @override
  String get privacyGateSummaryImportExport =>
      'L’importazione, l’esportazione, i backup completi e la condivisione avvengono solo quando li avvii esplicitamente. I backup completi dell’app escludono le chiavi API personalizzate e l’analisi di testo / HTML dell’orario invia solo il contenuto fornito all’endpoint di analisi configurato.';

  @override
  String get privacyGateSummaryUpdates =>
      'Se una versione successiva cambia il modo in cui vengono gestiti i dati, l\'app potrebbe chiederti di rivedere di nuovo l\'informativa aggiornata.';

  @override
  String get schoolWebImportEntry => 'Importa dalla pagina web della scuola';

  @override
  String get schoolWebImportEntryDesc =>
      'Importa la pagina dell\'orario corrente dal sito della scuola.';

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
  String get schoolSitesImportPreviewTitle =>
      'Verifica l’importazione dei siti scolastici';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount siti validi, $invalidCount voci non valide.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Il file contiene un elenco vuoto di siti scolastici.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'La voce $position non è valida e verrà ignorata.';
  }

  @override
  String get schoolSitesImportMerge => 'Unisci';

  @override
  String get schoolSitesImportReplace => 'Sostituisci';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Sostituire i siti scolastici attuali?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Verranno rimossi $currentCount siti attuali e salvati $importedCount siti importati. L’operazione non può essere annullata.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'I dati dei siti scolastici devono essere recuperati';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked non ha potuto leggere il file dei siti scolastici né il suo backup. Sono state create copie protette prima di bloccare le scritture.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'L’archivio dei siti scolastici non è disponibile';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked non può accedere all’archivio dei siti scolastici al momento. Controlla l’accesso all’archivio e la disponibilità del dispositivo, poi riprova. I dati attuali dei siti non verranno sovrascritti.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'I file di recupero e i percorsi di archiviazione interessati sono elencati qui sotto. Non modificare alcun file finché l’elenco dei siti non è stato recuperato.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Ricomincia senza siti scolastici';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Ricominciare con un elenco vuoto di siti scolastici?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Le copie protette verranno conservate, ma Sked creerà un nuovo file vuoto dei siti scolastici. Continua solo se non vuoi prima riprovare il recupero.';

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
  String get schoolWebImportUnsupportedPlatform =>
      'Questa piattaforma non supporta ancora il login web incorporato. Usa una piattaforma con supporto WebView.';

  @override
  String get schoolWebImportNoSchools =>
      'Nessuna configurazione scolastica disponibile. Controlla prima school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Impossibile caricare la configurazione della scuola. Riprova.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importa pagina corrente';

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
  String get schoolImportParserSettingsTitle => 'API per importare l’orario';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configura l’API compatibile con OpenAI per importare gli orari, non per un assistente di chat.';

  @override
  String get schoolImportParserSourceTitle => 'Sorgente del parser';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'OpenAI-compatibile personalizzato';

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
      'La chiave API personalizzata viene conservata nell’archivio sicuro della piattaforma, quando disponibile. Usa credenziali del parser personalizzato ed endpoint HTTP solo su dispositivi, browser e reti di cui ti fidi.';

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
  String get clearAppData => 'Cancella i dati';

  @override
  String get clearAppDataDesc =>
      'Elimina definitivamente tutti i dati locali di Sked ed esci dall’app';

  @override
  String get clearAppDataConfirmTitle => 'Cancellare tutti i dati di Sked?';

  @override
  String get clearAppDataConfirmMessage =>
      'Questa operazione elimina definitivamente orari, agende, impostazioni, siti scolastici, backup locali, copie di recupero e la chiave API IA, poi chiude Sked. I file esportati altrove non vengono eliminati. L’operazione non può essere annullata.';

  @override
  String get clearAppDataAction => 'Cancella i dati ed esci';

  @override
  String get clearAppDataFailed =>
      'Impossibile cancellare tutti i dati locali. Sked resterà aperto per consentirti di riprovare.';

  @override
  String get clearAppDataExitFailed =>
      'I dati locali sono stati cancellati, ma Sked non ha potuto chiudersi. Chiudi l’app manualmente prima di usarla di nuovo.';

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
      'L\'orario selezionato per la sostituzione non è disponibile. Selezionalo di nuovo.';

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
  String get generalSchedule => 'Agenda';

  @override
  String get studentTimetable => 'Orario';

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
  String get firstLaunchPrivacyConsentBefore =>
      'Scegliendo uno spazio di lavoro iniziale, confermi di aver letto e accettato l\'';

  @override
  String get firstLaunchPrivacyConsentLink => 'Informativa sulla privacy';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Cambia modalità';

  @override
  String get switchToStudentTimetable => 'Passa all’orario';

  @override
  String get today => 'Oggi';

  @override
  String get addEvent => 'Aggiungi evento';

  @override
  String get editEvent => 'Modifica evento';

  @override
  String get eventTitle => 'Titolo';

  @override
  String get eventTitleRequired => 'Inserisci un titolo';

  @override
  String get eventStartTime => 'Ora di inizio';

  @override
  String get eventEndTime => 'Ora di fine';

  @override
  String get eventDate => 'Data';

  @override
  String get eventTime => 'Ora';

  @override
  String get eventNotes => 'Note';

  @override
  String get eventColor => 'Colore';

  @override
  String get eventRecurrence => 'Ripetizione';

  @override
  String get recurrenceNone => 'Non si ripete';

  @override
  String get recurrenceWeekly => 'Settimanale';

  @override
  String get recurrenceEndDate => 'Data di fine';

  @override
  String get repeatsWeekly => 'Si ripete ogni settimana';

  @override
  String recurrenceUntil(Object date) {
    return 'Fino al $date';
  }

  @override
  String get switchToGeneralSchedule => 'Passa all’agenda';

  @override
  String get generalDisplaySettings =>
      'Impostazioni generali di visualizzazione';

  @override
  String get generalDisplaySettingsDesc =>
      'Viste, barra degli strumenti, formato data e aggiunta rapida';

  @override
  String get closePopupOnOutsideTap => 'Chiudi il popup toccando all’esterno';

  @override
  String get showGridLines => 'Mostra le linee della griglia';

  @override
  String get generalScheduleImportExport =>
      'Importazione ed esportazione delle categorie';

  @override
  String get generalScheduleImportExportDesc =>
      'Importa o condividi le categorie dell’agenda';

  @override
  String get importGeneralSchedules => 'Importa categorie';

  @override
  String get importGeneralSchedulesDesc => 'Leggi le categorie da un file JSON';

  @override
  String get shareGeneralSchedules => 'Condividi categorie';

  @override
  String get shareGeneralSchedulesDesc =>
      'Condividi le categorie come file JSON';

  @override
  String get saveGeneralSchedules => 'Salva categorie';

  @override
  String get saveGeneralSchedulesDesc => 'Salva le categorie come file JSON';

  @override
  String get selectSchedulesToExport => 'Seleziona le categorie da esportare';

  @override
  String get selectSchedulesToImport => 'Seleziona le categorie da importare';

  @override
  String generalScheduleEventCount(int count) {
    return 'Eventi: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Importate $count categorie';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Aggiungere i dati importati come nuova categoria o sostituirne una esistente?';

  @override
  String get addAsNewSchedule => 'Aggiungi come nuova categoria';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Seleziona almeno una categoria.';

  @override
  String get noExportableScheduleMessage =>
      'Nessuna categoria disponibile da esportare.';

  @override
  String get noSchedulesInImportMessage =>
      'Il file importato non contiene categorie.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Scegli una sola categoria importata per la sostituzione.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'La categoria selezionata per la sostituzione non è disponibile.';

  @override
  String get calendars => 'Categorie';

  @override
  String get calendar => 'Categoria';

  @override
  String get viewWeek => 'Settimana';

  @override
  String get viewDay => 'Giorno';

  @override
  String get viewList => 'Elenco';

  @override
  String get viewMonth => 'Mese';

  @override
  String visibleCategoryCount(int count) {
    return '$count categorie';
  }

  @override
  String get noVisibleCategories => 'Nessuna categoria visibile';

  @override
  String get selectCategoryToReplace => 'Scegli la categoria da sostituire';

  @override
  String get replaceCategory => 'Sostituisci categoria';

  @override
  String get deleteEventTitle => 'Elimina evento';

  @override
  String get deleteEventConfirmation =>
      'Questo evento verrà eliminato definitivamente.';

  @override
  String get deleteRecurringEventTitle => 'Elimina evento ricorrente';

  @override
  String get eventDuplicated => 'Evento duplicato';

  @override
  String get allDay => 'Tutto il giorno';

  @override
  String get collapseAllDayTimeline => 'Comprimi gli eventi di tutto il giorno';

  @override
  String get expandAllDayTimeline => 'Espandi gli eventi di tutto il giorno';

  @override
  String allDayEventsCount(int count) {
    return '$count eventi di tutto il giorno';
  }

  @override
  String moreEvents(int count) {
    return '+$count altri';
  }

  @override
  String get noMatchingEvents => 'Nessun evento corrispondente';

  @override
  String get noUpcomingEvents => 'Nessun evento in arrivo';

  @override
  String get addCalendar => 'Aggiungi categoria';

  @override
  String get newCalendar => 'Nuova categoria';

  @override
  String get hideCalendar => 'Nascondi categoria';

  @override
  String get showCalendar => 'Mostra categoria';

  @override
  String get rename => 'Rinomina';

  @override
  String get renameCalendar => 'Rinomina categoria';

  @override
  String get name => 'Nome';

  @override
  String get deleteCalendar => 'Elimina categoria';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Eliminare «$name»?';
  }

  @override
  String get deleteThisOccurrence => 'Elimina questa occorrenza';

  @override
  String get deleteFutureOccurrences => 'Elimina questa e le successive';

  @override
  String get deleteAllOccurrences => 'Elimina l’intera serie';

  @override
  String get duplicateEvent => 'Duplica';

  @override
  String get repeatsDaily => 'Si ripete ogni giorno';

  @override
  String get repeatsMonthly => 'Si ripete ogni mese';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Si ripete ogni $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count volte';
  }

  @override
  String get recurrenceDaily => 'Giornaliera';

  @override
  String get recurrenceMonthly => 'Mensile';

  @override
  String get recurrenceCustom => 'Personalizzata';

  @override
  String get recurrenceEvery => 'Ogni';

  @override
  String get recurrenceUnit => 'Unità';

  @override
  String get recurrenceDays => 'Giorni';

  @override
  String get recurrenceWeeks => 'Settimane';

  @override
  String get recurrenceMonths => 'Mesi';

  @override
  String get recurrenceRepeatCount => 'Numero di ripetizioni';

  @override
  String get recurrenceNoLimit => 'Senza limite';

  @override
  String get recurrencePositiveNumber => 'Inserisci un numero positivo';

  @override
  String get clearEndDate => 'Rimuovi la data di fine';

  @override
  String get pickDate => 'Scegli la data';

  @override
  String get pickTime => 'Scegli l’ora';

  @override
  String get reminder => 'Promemoria';

  @override
  String get reminderAtStart => 'All’inizio';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min prima';
  }

  @override
  String get reminderHourBefore => '1 ora prima';

  @override
  String get reminderDayBefore => '1 giorno prima';

  @override
  String get markReminderHandled => 'Segna come gestito';

  @override
  String get restoreReminder => 'Ripristina il promemoria nell’app';

  @override
  String get reminderHandled => 'Promemoria nell’app segnato come gestito';

  @override
  String get reminderRestored => 'Promemoria nell’app ripristinato';

  @override
  String get reminderUpcoming => 'In arrivo';

  @override
  String get generalFitWeekColumnsToWidth => 'Adatta la settimana allo schermo';

  @override
  String get showWeekends => 'Mostra i fine settimana';

  @override
  String get startHour => 'Ora iniziale';

  @override
  String get endHour => 'Ora finale';

  @override
  String get timeGridDensity => 'Densità della griglia oraria';

  @override
  String get timeGridHourHeight => 'Altezza delle righe orarie';

  @override
  String get timeGridHourHeightHint =>
      'Regola la scala verticale delle viste giornaliera e settimanale senza cambiare l’intervallo della griglia di 15, 30 o 60 minuti.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Importa file JSON';

  @override
  String get pasteJson => 'Incolla JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Importa le categorie dal JSON copiato';

  @override
  String get importIcsFile => 'Importa file ICS';

  @override
  String get importIcsFileDesc => 'Leggi gli eventi da un file calendario .ics';

  @override
  String get pasteIcs => 'Incolla ICS';

  @override
  String get pasteIcsDesc =>
      'Importa gli eventi dal testo di calendario copiato';

  @override
  String get copyJson => 'Copia JSON';

  @override
  String get copyJsonDesc => 'Copia le categorie selezionate come testo JSON';

  @override
  String get shareIcs => 'Condividi ICS';

  @override
  String get shareIcsDesc => 'Condividi i calendari selezionati come .ics';

  @override
  String get saveIcs => 'Salva ICS';

  @override
  String get saveIcsDesc => 'Salva i calendari selezionati come .ics';

  @override
  String get copyIcs => 'Copia ICS';

  @override
  String get copyIcsDesc => 'Copia i calendari selezionati come testo ICS';

  @override
  String get importIcs => 'Importa ICS';

  @override
  String get icsContent => 'Contenuto ICS';

  @override
  String get pasteIcsContentHint =>
      'Incolla qui il contenuto che inizia con BEGIN:VCALENDAR';

  @override
  String get icsReminderExportTitle =>
      'L’esportazione ICS non include i promemoria';

  @override
  String get icsReminderExportMessage =>
      'I promemoria non sono inclusi nel file ICS esportato. Scegli JSON per conservare le impostazioni dei promemoria.';

  @override
  String get icsReminderExportJsonAction => 'Esporta JSON';

  @override
  String get icsReminderExportContinueAction => 'Continua con ICS';

  @override
  String get icsReminderImportNotice =>
      'I promemoria degli eventi importati da ICS saranno disattivati. Usa JSON per ripristinare le impostazioni dei promemoria.';

  @override
  String get icsReminderReplaceTitle => 'Sostituire eventi e promemoria?';

  @override
  String icsReminderReplaceMessage(String calendar) {
    return 'Sostituendo «$calendar» con eventi ICS, gli eventi della categoria verranno sovrascritti e i relativi promemoria disattivati. Annulla per esportare prima un backup JSON, oppure torna indietro e aggiungi una nuova categoria.';
  }

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Trovati $count eventi. Aggiungerli come nuova categoria o sostituirne una esistente?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Importate $count categorie con $warningCount avvisi';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Ignorato un evento senza ora di inizio.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Ignorato un evento con un’ora di inizio non supportata.';

  @override
  String get importWarningAdjustedEnd =>
      'Corretta l’ora di fine di un evento perché non era successiva all’ora di inizio.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'I campi ICS non supportati sono stati ignorati: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Ignorata la frequenza di ripetizione non supportata: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Seleziona i calendari da copiare come ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Seleziona i calendari da esportare come ICS';

  @override
  String get exportIcsText => 'Esporta testo ICS';

  @override
  String get exportJsonText => 'Esporta testo JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'I dati dell’app sono stati ripristinati dal backup precedente perché non è stato possibile caricare il file principale.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Il file dei dati principale e il suo backup sono entrambi danneggiati. L’app sta usando uno stato iniziale.';

  @override
  String get dataRecoveryCorruptTitle => 'I tuoi dati devono essere recuperati';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked non ha potuto leggere il file dei dati principale né il suo backup. Sono state create copie protette prima di bloccare le scritture.';

  @override
  String get dataRecoveryIoFailureTitle => 'L’archiviazione non è disponibile';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked non può accedere all’archiviazione locale al momento. Controlla l’accesso all’archiviazione e la disponibilità del dispositivo, poi riprova. I dati esistenti non verranno sovrascritti.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Aggiorna Sked per aprire questi dati';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Questi dati sono stati creati con una versione più recente di Sked. Aggiorna l’app prima di riprovare. Il riavvio con dati vuoti è disabilitato per proteggerli.';

  @override
  String get dataRecoveryRetryAction => 'Riprova';

  @override
  String get dataRecoveryArtifactsHint =>
      'I file di recupero e i percorsi di archiviazione interessati sono elencati qui sotto. Non modificare alcun file finché i dati non sono stati recuperati.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Mostra file e percorsi di recupero';

  @override
  String get dataRecoveryStartFreshAction => 'Ricomincia con nuovi dati';

  @override
  String get dataRecoveryStartFreshConfirmTitle =>
      'Ricominciare con nuovi dati?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Le copie protette verranno conservate, ma Sked creerà un nuovo file di dati locale. Continua solo se non vuoi prima riprovare il recupero.';

  @override
  String get previousMonth => 'Mese precedente';

  @override
  String get nextMonth => 'Mese successivo';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'In corso';

  @override
  String get deleteCourseTitle => 'Elimina corso';

  @override
  String get deleteCourseMessage => 'Eliminare questo corso?';

  @override
  String get showLunarCalendar => 'Mostra il calendario lunare';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count eventi';
  }

  @override
  String get defaultView => 'Vista predefinita';

  @override
  String get generalDefaultViewSection => 'All’avvio';

  @override
  String get generalViewSwitchBehavior => 'Pulsante di cambio vista';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Nascondi la navigazione tra le aree di lavoro';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Nascondi la navigazione degli spazi di lavoro. Puoi passare a un altro spazio dal menu della schermata principale.';

  @override
  String get generalDateLabelFormat => 'Formato della data';

  @override
  String get generalDateLabelFormatLocalized => 'Localizzato (lug 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Barre (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection =>
      'Disposizione della barra degli strumenti';

  @override
  String get toolbarNavigationSection =>
      'Navigazione nella barra degli strumenti';

  @override
  String get toolbarNavigationHiddenBehavior => 'Elementi nascosti';

  @override
  String get toolbarNavigationRemove => 'Nascondi completamente';

  @override
  String get toolbarNavigationMore => 'Sposta in Altro';

  @override
  String get toolbarNavigationReorder =>
      'Riordina gli elementi della barra degli strumenti';

  @override
  String get toolbarNavigationVisibility =>
      'Mostra l’elemento della barra degli strumenti';

  @override
  String get toolbarNavigationTimetable => 'Selettore dell’orario';

  @override
  String get toolbarNavigationWeek => 'Selettore della settimana';

  @override
  String get toolbarNavigationView => 'Selettore della vista';

  @override
  String get toolbarNavigationCategory => 'Selettore della categoria';

  @override
  String get toolbarNavigationDate => 'Selettore della data';

  @override
  String get generalToolbarWidthPolicy =>
      'Distribuzione dello spazio nella barra degli strumenti';

  @override
  String get generalToolbarWidthContent => 'Distribuzione automatica';

  @override
  String get generalToolbarWidthBalanced => 'Bilanciata';

  @override
  String get generalToolbarWidthCalendarPriority => 'Priorità alla categoria';

  @override
  String get generalToolbarWidthDatePriority => 'Priorità alla data';

  @override
  String get generalViewSwitchCycle => 'Scorri le viste in sequenza';

  @override
  String get generalViewSwitchMenu => 'Apri il menu delle viste';

  @override
  String get generalViewSwitchTooltip => 'Cambia vista';

  @override
  String get generalViewSwitchMenuTooltip => 'Scegli vista';

  @override
  String get generalViewLongPressTodayHint => 'Tieni premuto per andare a oggi';

  @override
  String get generalScheduleDisplaySection => 'Visualizzazione dell’agenda';

  @override
  String get generalTimeGridSection => 'Griglia oraria';

  @override
  String get generalPopupSection => 'Comportamento dei popup';

  @override
  String get quickActionsSection => 'Azioni rapide';

  @override
  String get showAddCourseFab =>
      'Mostra il pulsante flottante per aggiungere corsi';

  @override
  String get showAddCourseFabHint =>
      'Mostra o nascondi il pulsante flottante per aggiungere corsi nell’angolo inferiore destro dell’orario.';

  @override
  String get showAddEventFab =>
      'Mostra il pulsante flottante per aggiungere eventi';

  @override
  String get showAddEventFabHint =>
      'Mostra o nascondi il pulsante flottante per aggiungere eventi nell’angolo inferiore destro dell’agenda.';

  @override
  String get enableLongPressAddCourse =>
      'Tieni premuta un’area vuota per aggiungere corsi';

  @override
  String get enableLongPressAddCourseHint =>
      'Tieni premuta un’area vuota della griglia dell’orario per aggiungere un corso.';

  @override
  String get enableLongPressAddEvent =>
      'Tieni premuta un’area vuota per aggiungere eventi';

  @override
  String get enableLongPressAddEventHint =>
      'Nella vista giornaliera o settimanale, tieni premuta un’area vuota della griglia oraria per aggiungere un evento.';

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
  String get developerNotificationDiagnostics => 'Diagnostica delle notifiche';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Controlla lo stato di consegna su Android, ricrea il piano dei promemoria esistente e invia notifiche di prova sicure tramite il normale servizio di notifiche di Sked.';

  @override
  String get developerNotificationUnsupported =>
      'La diagnostica delle notifiche è disponibile solo su Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'La diagnostica delle notifiche sarà disponibile dopo l’avvio del coordinatore dell’agenda.';

  @override
  String get developerNotificationRefresh => 'Aggiorna diagnostica';

  @override
  String get developerNotificationSystemStatus =>
      'Autorizzazione alle notifiche di sistema';

  @override
  String get developerNotificationPermissionAllowed => 'Consentita';

  @override
  String get developerNotificationPermissionBlocked => 'Bloccata';

  @override
  String get developerNotificationExactAlarm => 'Sveglie esatte';

  @override
  String get developerNotificationExactAlarmAllowed => 'Consentite';

  @override
  String get developerNotificationExactAlarmBlocked => 'Non consentite';

  @override
  String get developerNotificationPlan => 'Piano delle notifiche dell’agenda';

  @override
  String get developerNotificationCoverage => 'Copertura dei promemoria';

  @override
  String get developerNotificationCoverageReady =>
      'Tutti i promemoria noti con durata finita sono programmati direttamente';

  @override
  String get developerNotificationCoverageRenewable =>
      'I promemoria ricorrenti vengono riprogrammati a lungo termine per quanto possibile';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'La capacità delle sveglie dirette è esaurita; i promemoria successivi vengono riprogrammati per quanto possibile';

  @override
  String get developerNotificationCoverageBlocked =>
      'Le condizioni per una consegna precisa non sono soddisfatte';

  @override
  String get developerNotificationCoverageFailed =>
      'L’ultima sincronizzazione dei promemoria non è riuscita';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled sveglie dirette / capacità: $capacity';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Ultimo errore: $message';
  }

  @override
  String get developerNotificationTestChannel => 'Canale di prova';

  @override
  String get developerNotificationTestCourse => 'Promemoria dei corsi';

  @override
  String get developerNotificationTestSchedule => 'Promemoria degli eventi';

  @override
  String get developerNotificationImmediateTest => 'Invia una prova immediata';

  @override
  String get developerNotificationThirtySecondTest =>
      'Programma una prova in background tra 30 secondi';

  @override
  String get developerNotificationImmediateQueued =>
      'Notifica di prova immediata inviata.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Prova in background programmata tra 30 secondi.';

  @override
  String get developerNotificationAppSwitch =>
      'Interruttore dei promemoria dell’app';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Attivo per i promemoria normali';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Disattivo per i promemoria normali; i test per sviluppatori restano disponibili';

  @override
  String get developerNotificationTimeZone => 'Fuso orario locale';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Non ancora creato. Verrà creato da un test per sviluppatori.';

  @override
  String get developerNotificationChannelEnabledState => 'Attivo';

  @override
  String get developerNotificationChannelBlockedState => 'Bloccato';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Importanza: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Importanza non disponibile';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending in attesa / $active attive';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Ultima visualizzazione nativa: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Nessuna riconciliazione ancora registrata.';

  @override
  String get developerNotificationNextReminder => 'Prossimo promemoria reale';

  @override
  String get developerNotificationNoPendingReminder =>
      'Nessun promemoria futuro nel piano attuale';

  @override
  String get developerNotificationNextRenewal =>
      'Prossima riprogrammazione non garantita';

  @override
  String get developerNotificationLastSynchronization =>
      'Ultima sincronizzazione dei promemoria';

  @override
  String get developerNotificationLateRecovery =>
      'Recupero dei promemoria in ritardo';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count promemoria sono stati recuperati dopo l’orario originale';
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
  String get developerNotificationReconcileOriginForeground => 'Primo piano';

  @override
  String get developerNotificationReconcileOriginBackground => 'Background';

  @override
  String get developerNotificationReconcileModeAuthoritative => 'Autoritativa';

  @override
  String get developerNotificationReconcileModeRecovery => 'Recupero';

  @override
  String get developerNotificationRunRecovery =>
      'Esegui il recupero dei promemoria';

  @override
  String get developerNotificationRecoveryComplete =>
      'Recupero dei promemoria completato';

  @override
  String get developerNotificationReconcileResultSuccess => 'Riuscita';

  @override
  String get developerNotificationReconcileResultSkipped => 'Ignorata';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Bloccata finché non sono soddisfatte tutte le condizioni per una consegna precisa';

  @override
  String get developerNotificationReconcileResultFailed => 'Non riuscita';

  @override
  String get developerNotificationBackgroundLimits =>
      'Limiti in background del produttore';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Le restrizioni in background del produttore possono influire sulla consegna.';

  @override
  String get developerNotificationAutostart =>
      'Avvio in background del produttore';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Produttore: $vendor; è disponibile un accesso alle sue impostazioni. Android non permette di leggere lo stato dell’autorizzazione.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Produttore: $vendor; verranno aperti i dettagli dell’app come alternativa. Android non permette di leggere lo stato dell’autorizzazione.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Non è disponibile un accesso alle impostazioni in background del produttore.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Ultima destinazione aperta: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'impostazioni del produttore';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'dettagli dell’app';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'nessuna';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Limiti del recupero dopo il riavvio';

  @override
  String get developerNotificationRebootBoundary =>
      'Il recupero inizia dopo il primo sblocco; un’app arrestata forzatamente non può avviarsi da sola.';

  @override
  String get developerNotificationTestChecking =>
      'I test non sono disponibili durante il controllo dello stato delle notifiche.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'I test non sono disponibili perché le notifiche di sistema sono bloccate.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'I test non sono disponibili perché il canale di notifica selezionato è bloccato.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Gestita dalle impostazioni delle notifiche di Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Non applicabile su Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Identità del pacchetto Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Identità MSIX disponibile; le notifiche visualizzate possono essere rimosse';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Installa la versione MSIX per rimuovere in modo affidabile le notifiche visualizzate';

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
  String get notificationSettingsSection => 'Promemoria e notifiche';

  @override
  String get notificationCoverage => 'Copertura dei promemoria';

  @override
  String get notificationCoverageBlocked =>
      'Reminders are blocked and will not fire. Review the system requirements below.';

  @override
  String get notificationCoverageFailed =>
      'Reminders could not be synced. Open notification settings and try again.';

  @override
  String get notificationCoverageRenewable =>
      'Gli eventi ricorrenti senza data di fine vengono riprogrammati in background per mantenere la copertura a lungo termine.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android può programmare direttamente fino a $capacity promemoria; si tenta di riprogrammare in anticipo quelli successivi.';
  }

  @override
  String get notificationSettingsEnabled => 'Attiva promemoria e notifiche';

  @override
  String get notificationSettingsEnabledHint =>
      'Programma solo gli elementi con un promemoria. Imposta sotto un promemoria predefinito per i corsi che lo ereditano.';

  @override
  String get notificationPrecisionLimitations =>
      'I promemoria dipendono dalle autorizzazioni e dall’esecuzione in background. Spegnimenti, cambi d’ora o limitazioni del sistema possono ritardarli.';

  @override
  String get notificationSettingsEnabledSummary => 'Attivo';

  @override
  String get notificationSettingsDisabledSummary => 'Disattivo';

  @override
  String get notificationDefaultsSection => 'Promemoria predefiniti';

  @override
  String get notificationCourseDefaultReminder =>
      'Promemoria predefinito dei corsi';

  @override
  String get notificationGeneralDefaultReminder =>
      'Promemoria predefinito degli eventi';

  @override
  String get notificationReminderOff => 'Nessun promemoria';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minuti prima';
  }

  @override
  String get notificationPermission => 'Autorizzazione alle notifiche';

  @override
  String get notificationPermissionGranted => 'Consentita dal sistema';

  @override
  String get notificationPermissionDenied => 'Bloccata dal sistema';

  @override
  String get notificationPermissionChecking => 'Verifica dell’autorizzazione…';

  @override
  String get notificationPermissionRequest => 'Richiedi autorizzazione';

  @override
  String get notificationPermissionOpenSettings =>
      'Apri le impostazioni di sistema';

  @override
  String get notificationPermissionRequestFailed =>
      'Impossibile leggere l’autorizzazione alle notifiche. Riprova.';

  @override
  String get notificationExactAlarm => 'Autorizzazione alle sveglie esatte';

  @override
  String get notificationExactAlarmAllowed => 'Consentita dal sistema';

  @override
  String get notificationExactAlarmRequired =>
      'Necessaria per promemoria a orari precisi';

  @override
  String get notificationExactAlarmRequest => 'Consenti le sveglie esatte';

  @override
  String get notificationBatteryOptimization => 'Ottimizzazione della batteria';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Esclusa dall’ottimizzazione della batteria di Android';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Per promemoria precisi serve un’esenzione dall’ottimizzazione della batteria di Android';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Apri le impostazioni di ottimizzazione della batteria';

  @override
  String get notificationAutostart => 'Avvio in background del produttore';

  @override
  String get notificationAutostartVendorHint =>
      'Consenti l’avvio automatico o l’esecuzione in background per ripristinare i promemoria dopo un riavvio.';

  @override
  String get notificationAutostartFallbackHint =>
      'Apri i dettagli di Sked e consenti l’esecuzione in background. Android non può verificare questa impostazione del produttore.';

  @override
  String get notificationAutostartUnavailable =>
      'Nessuna pagina di impostazioni del produttore trovata. Controlla manualmente i dettagli di Sked.';

  @override
  String get notificationAutostartRequest =>
      'Apri le impostazioni in background del produttore';

  @override
  String get notificationAutostartOpenFailed =>
      'Impossibile aprire le impostazioni in background del produttore. Controlla manualmente i dettagli di Sked.';

  @override
  String get notificationLockScreenTitles =>
      'Mostra i titoli sulla schermata di blocco';

  @override
  String get notificationLockScreenTitlesHint =>
      'Se disattivata, i dettagli delle notifiche restano privati sulla schermata di blocco.';

  @override
  String get notificationPlatformUnsupported =>
      'Questa piattaforma non offre notifiche native.';

  @override
  String get workspaceFeatures => 'Gestione funzionalità';

  @override
  String get workspaceBoth => 'Orario e agenda';

  @override
  String get workspaceOnlyStudent => 'Solo orario';

  @override
  String get workspaceOnlyGeneral => 'Solo agenda';

  @override
  String get workspaceDisableTitle => 'Disattivare questo spazio?';

  @override
  String get workspaceDisableMessage =>
      'I dati e le preferenze saranno conservati. Funzioni e promemoria saranno sospesi finché non lo riattivi qui.';

  @override
  String get workspaceEnableHint =>
      'Scegli le funzioni da usare. Almeno una deve rimanere attiva.';

  @override
  String get workspaceLastRequired => 'Almeno uno spazio deve rimanere attivo.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Lo spazio è disattivato, ma non è stato possibile rimuovere i promemoria. Riprova il ripristino delle notifiche.';

  @override
  String get settingsDataPrivacy => 'Dati e privacy';

  @override
  String get selectedDayAgenda => 'Giorno selezionato';

  @override
  String get notificationTroubleshooting =>
      'Autorizzazioni e risoluzione dei problemi';

  @override
  String get settingsConnection => 'Connessione';

  @override
  String get settingsAdvanced => 'Avanzate';

  @override
  String get unsavedChangesMessage =>
      'Hai modifiche non salvate. Scartarle e uscire?';

  @override
  String get backupWorkspaceSelection =>
      'Il backup completo include i dati e la selezione degli spazi attivi.';

  @override
  String get assistantLayoutPreview => 'IA · Anteprima della disposizione';

  @override
  String get assistantSelectionContext =>
      'Usa la selezione attuale come contesto';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Bozza del messaggio';

  @override
  String get assistantPreviewNoSend =>
      'Solo anteprima della disposizione. Non verrà inviato o modificato nulla.';

  @override
  String get resizePanel => 'Ridimensiona il pannello';

  @override
  String get minimizeWindow => 'Riduci a icona';

  @override
  String get maximizeWindow => 'Ingrandisci';

  @override
  String get restoreWindow => 'Ripristina finestra';

  @override
  String get closeWindow => 'Chiudi finestra';

  @override
  String get courseSystemReminder => 'Promemoria di sistema';

  @override
  String courseReminderInherit(String reminder) {
    return 'Usa il valore predefinito ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'I promemoria di sistema sono disattivati nelle impostazioni delle notifiche. Questa preferenza del corso può comunque essere salvata.';

  @override
  String get courseReminderDefaultOff =>
      'Non è impostato un promemoria predefinito per i corsi. Scegline uno personalizzato qui o imposta un valore predefinito nelle impostazioni delle notifiche.';

  @override
  String get courseReminderDeliveryHint =>
      'Questa preferenza viene salvata con il corso. La consegna dipende dalle autorizzazioni di notifica del sistema e dalle restrizioni in background.';

  @override
  String get courseReminderPermissionUnknown =>
      'Lo stato delle notifiche di sistema non è stato verificato. Controlla le impostazioni delle notifiche prima di fare affidamento sui promemoria.';

  @override
  String get courseReminderMinutesLabel => 'Minuti prima della lezione';

  @override
  String get exportAction => 'Esporta';

  @override
  String get datePickerSelectWeek => 'Seleziona settimana';

  @override
  String get datePickerSelectMonth => 'Seleziona mese';

  @override
  String get generalDateLabelFormatDescription =>
      'Si applica alla navigazione per data su desktop e schermi piccoli.';

  @override
  String get dateRangeTitle => 'Scegli intervallo di date';

  @override
  String get dateRangeCustom => 'Personalizzato';

  @override
  String get dateRangeChooseStart => 'Scegli la data iniziale';

  @override
  String get dateRangeChooseEnd => 'Scegli la data finale';

  @override
  String get dateRangeLimit => 'Seleziona da 1 a 14 giorni, estremi inclusi.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni',
      one: '1 giorno',
    );
    return 'Personalizzato · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Seleziona con le rotelle';

  @override
  String get courseReminderUseDefault => 'Usa il valore predefinito';

  @override
  String get courseReminderInvalidMinutes =>
      'Inserisci un numero intero di minuti maggiore o uguale a zero.';

  @override
  String get generalCustomColumnWidth =>
      'Larghezza delle colonne della vista personalizzata';

  @override
  String get generalCustomColumnWidthAuto => 'Automatica';

  @override
  String get generalCustomColumnWidthManual => 'Larghezza minima';

  @override
  String get generalCustomColumnWidthMinimum => 'Larghezza minima per giorno';

  @override
  String get generalCustomColumnWidthHint =>
      'Tutte le date condividono questa larghezza minima. Le colonne riempiono lo spazio disponibile oppure scorrono orizzontalmente. Si applica solo alla vista personalizzata.';

  @override
  String get settingsAppearanceLanguage => 'Aspetto e lingua';

  @override
  String get settingsAppearanceDetails => 'Colori e contorni';

  @override
  String get monthNoEvents => 'Nessun evento in questo giorno';

  @override
  String get settingsOverview => 'Panoramica';

  @override
  String get settingsThemeTarget => 'Tema per';

  @override
  String get settingsColorMode => 'Modalità colore';

  @override
  String get settingsNotificationPreferences => 'Preferenze dei promemoria';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Promemoria predefiniti, autorizzazioni e affidabilità';

  @override
  String get settingsFeaturesSummary => 'Aree di lavoro e navigazione';

  @override
  String get settingsPrivacySummary =>
      'Informativa sulla privacy e cancellazione dei dati locali';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count periodi',
      one: '1 periodo',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Periodo';

  @override
  String get periodTimesDurationColumn => 'Durata';

  @override
  String get periodTimesGapColumn => 'Pausa';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'In attesa di salvataggio…';

  @override
  String get periodTimesSaveFailed => 'Non salvato · Salvataggio non riuscito';

  @override
  String get periodTimesInvalidStatus =>
      'Non salvato · Correggi gli orari evidenziati';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked non può confermare se l’ultimo salvataggio è stato annullato. La scrittura è sospesa e le copie di recupero sono conservate. Controlla lo spazio di archiviazione e riprova a caricare i dati.';

  @override
  String get settingsPanelDisplayMode => 'Visualizzazione pannelli';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Condivisa tra orari e calendari';

  @override
  String get settingsPanelDisplayOverlay => 'Sovrapposti';

  @override
  String get settingsPanelDisplaySideBySide => 'Affiancati';

  @override
  String get settingsPanelDisplayAutomatic => 'Automatica';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Si sovrappone a destra senza ridimensionare il calendario.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Preferisce i pannelli affiancati; li sovrappone solo se il calendario diventa troppo stretto.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Affianca i pannelli se il calendario rimane leggibile, altrimenti li sovrappone.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Disattivare Impostazioni o Area di lavoro nella barra degli strumenti li sposta in Altro anziché rimuoverli. Altro non può essere nascosto finché contiene azioni essenziali. Il cambio di area di lavoro appare solo quando la navigazione inferiore è nascosta e più aree di lavoro sono attive.';

  @override
  String get reminderEnded => 'Terminato';

  @override
  String get reminderAutoCloseHint =>
      'Si chiude dopo 10 secondi. Interagisci per mantenerlo aperto.';

  @override
  String get showReminderIndependently => 'Apri separatamente';

  @override
  String get categoryManagerTitle => 'Gestisci categorie';

  @override
  String get categoryHidden => 'Nascosta';

  @override
  String get categoryShowOnCalendar => 'Mostra nel calendario';

  @override
  String get categoryHideOnCalendar => 'Nascondi dal calendario';

  @override
  String get categoryEditColor => 'Cambia il colore della categoria';

  @override
  String get categoryThemePalette => 'Tavolozza del tema';

  @override
  String get categoryCustomColor => 'Personalizzato';

  @override
  String get colorHexInvalid => 'Inserisci un colore esadecimale di sei cifre.';

  @override
  String get colorPickerHue => 'Tonalità';

  @override
  String get colorPickerSaturation => 'Saturazione';

  @override
  String get colorPickerValue => 'Luminosità';

  @override
  String get colorPickerHex => 'Colore esadecimale';

  @override
  String get colorPickerSpectrum => 'Spettro dei colori';

  @override
  String get colorPickerSpectrumKeyboardHint =>
      'Usa le frecce sinistra e destra per regolare la saturazione, e su e giù per regolare la luminosità.';

  @override
  String categoryColorSlot(int number) {
    return 'Colore del tema $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Gli aggiornamenti dello store possono arrivare più tardi. La disponibilità è indicata sulla pagina dello store.';

  @override
  String get storePrereleaseNotice =>
      'Ricevere avvisi sugli aggiornamenti preliminari non ti iscrive a un programma di test dello store.';

  @override
  String get updateFoundTitle => 'Nuova versione disponibile';

  @override
  String get updateNoNotes => 'Non sono state fornite note di rilascio.';

  @override
  String get updateLater => 'Più tardi';

  @override
  String get updateRetry => 'Riprova';

  @override
  String get updatePrerelease => 'Versione preliminare';

  @override
  String get updateNetworkFailure =>
      'Impossibile cercare aggiornamenti. Controlla la connessione e riprova.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Nessuna versione più recente trovata (attuale: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Ripristino del backup…';

  @override
  String get backupRestoreInProgressMessage =>
      'Potrai modificare dati e impostazioni al termine del ripristino. Puoi continuare a consultarli.';

  @override
  String get managePeriodTimeSets => 'Gestisci i set di orari delle lezioni';

  @override
  String periodTimeSetUsageSummary(int periodCount, int timetableCount) {
    return 'Fasce orarie: $periodCount · Orari associati: $timetableCount';
  }

  @override
  String chooseTimetableImportMethod(String name) {
    return 'Importa come nuovo orario oppure sostituisci tutti i dettagli e le lezioni dell\'orario «$name».';
  }

  @override
  String get selectAtLeastOneWeek => 'Seleziona almeno una settimana.';

  @override
  String get notificationRemindHiddenGeneralCalendars =>
      'Mantieni i promemoria per le categorie nascoste';

  @override
  String get notificationRemindHiddenGeneralCalendarsHint =>
      'Si applica ai promemoria nell\'app e alle notifiche di sistema. Le notifiche di sistema devono comunque essere attivate.';

  @override
  String get generalReminderFollowDefault => 'Usa impostazione predefinita';

  @override
  String get generalReminderCustom => 'Promemoria personalizzati';

  @override
  String get eventEditScopeTitle => 'Modifica evento ricorrente';

  @override
  String get eventEditThisOccurrence => 'Solo questa occorrenza';

  @override
  String get eventEditThisAndFollowing => 'Questa occorrenza e le successive';

  @override
  String get eventEditEntireSeries => 'Intera serie';

  @override
  String get eventEditEntireSeriesHint =>
      'Le modifiche si applicano all\'intera serie, comprese le occorrenze passate.';

  @override
  String get eventEditConflict =>
      'Questo evento è stato modificato. La bozza viene conservata; riapri l\'evento per controllare la versione più recente.';

  @override
  String eventSavedToHiddenCalendar(String name) {
    return 'Salvato nella categoria nascosta «$name».';
  }

  @override
  String get viewEvent => 'Visualizza evento';

  @override
  String get schoolSitesNameRequired => 'Inserisci il nome della scuola.';

  @override
  String get schoolSitesLoginUrlRequired => 'Inserisci un URL di accesso.';

  @override
  String get languageNoResults => 'Nessuna lingua corrispondente';

  @override
  String get themeGeneralMonthTextColors => 'Testo della vista mensile';

  @override
  String get themeGeneralFestivalTextColor => 'Feste e giorni festivi';

  @override
  String get themeGeneralSolarTermTextColor => 'Periodi solari';

  @override
  String get themeGeneralLunarTextColor => 'Date lunari';

  @override
  String get courseTextLowContrastHint =>
      'Questo colore del testo potrebbe essere poco leggibile su alcune schede dei corsi (contrasto inferiore a 4.5:1). Puoi mantenerlo o scegliere un altro colore.';

  @override
  String get shortenSemesterTitle => 'Accorciare il semestre?';

  @override
  String shortenSemesterMessage(int weeks, int count) {
    return 'Il semestre terminerà alla settimana $weeks. Corsi con lezioni successive: $count. I corsi e le settimane selezionate saranno conservati. Ripristina il numero di settimane per visualizzarli di nuovo.';
  }

  @override
  String get defaultGeneralCalendarName => 'Il mio calendario';

  @override
  String get icsImportReportTitle => 'Rapporto di importazione';

  @override
  String get icsImportReportAction => 'Visualizza rapporto';

  @override
  String get icsExportFailureTitle => 'Impossibile esportare in ICS';

  @override
  String get icsCopyDiagnosticsAction => 'Copia dettagli';

  @override
  String get icsUnsupportedTimeZoneMessage =>
      'Questo ICS contiene fusi orari con nome che Sked non può interpretare in sicurezza. Non è stato importato nulla. Esporta UTC oppure orari locali senza fuso dal calendario di origine e riprova.';

  @override
  String get icsExportMonthlyAnchorMismatchMessage =>
      'Questo evento mensile non può essere rappresentato con precisione in ICS. Esporta JSON per conservarne le date.';

  @override
  String get icsExportEmptyRecurrenceMessage =>
      'Questo evento ricorrente non ha occorrenze valide da esportare in ICS. Esporta JSON per conservare la voce.';

  @override
  String get icsImportedCalendarName => 'Calendario importato';

  @override
  String get icsUntitledEventName => 'Evento senza titolo';

  @override
  String notificationWindowsCoverageLimit(int days, int capacity) {
    return 'Windows programma promemoria solo per i prossimi $days giorni, fino a $capacity alla volta. Riapri regolarmente l’app per aggiornare il piano.';
  }

  @override
  String notificationWindowsCoverageSummary(int count, String date) {
    return 'Promemoria programmati: $count. L’ultima verifica copre il periodo fino al $date.';
  }

  @override
  String get notificationWindowsCoverageCapacityLimited =>
      'È stato raggiunto il limite di promemoria. Alcuni non sono ancora programmati. Riapri l’app dopo l’attivazione dei prossimi promemoria per aggiornare il piano.';

  @override
  String get courseInactiveThisWeek => 'Non in programma questa settimana';

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
  String get icsSkippedTimeZonesReview =>
      'The following events will be skipped because their time zones cannot be interpreted safely. Review the details before importing the remaining events.';

  @override
  String get icsImportRemainingAction => 'Continue with remaining events';

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
      'The repeat rule was kept. Dates missing from a month move to its last day; the source rule skips those dates.';

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
}
