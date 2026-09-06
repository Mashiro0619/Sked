// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Semaine $week';
  }

  @override
  String get addCourse => 'Ajouter un cours';

  @override
  String get settings => 'Paramètres';

  @override
  String get multiTimetableSwitch => 'Changer d\'emploi du temps';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Emploi du temps actuel · $weeks semaines';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Touchez pour changer · $weeks semaines';
  }

  @override
  String get editTimetable => 'Modifier l\'emploi du temps';

  @override
  String get schoolImportResultEditorTitle => 'Modifier le résultat analysé';

  @override
  String get schoolImportParsePageTitle => 'Analyser l’emploi du temps';

  @override
  String get schoolImportParsePageParsing => 'Analyse en cours…';

  @override
  String get schoolImportParsePageFailed => 'Échec de l’analyse';

  @override
  String get schoolImportParsePageComplete => 'Analyse terminée';

  @override
  String get schoolImportParsePageContinue => 'Continuer';

  @override
  String get schoolImportParsePageRawContent => 'Réponse brute';

  @override
  String get schoolImportParsePageExpandRaw => 'Développer la réponse brute';

  @override
  String get schoolImportParsePageCollapseRaw => 'Réduire la réponse brute';

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
  String get createTimetable => 'Nouvel emploi du temps';

  @override
  String get jumpToWeek => 'Aller à la semaine';

  @override
  String get timetable => 'Emploi du temps';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Nom de l\'emploi du temps';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Nombre total de semaines';

  @override
  String get delete => 'Supprimer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get deleteTimetableTitle => 'Supprimer l\'emploi du temps';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Supprimer \"$name\" ?';
  }

  @override
  String get noTimetableTitle => 'Aucun emploi du temps';

  @override
  String get noTimetableMessage =>
      'Créez un emploi du temps ou importez-en un depuis un fichier JSON.';

  @override
  String get importTimetable => 'Importer un emploi du temps';

  @override
  String get courseName => 'Nom du cours';

  @override
  String get location => 'Lieu';

  @override
  String get dayOfWeek => 'Jour';

  @override
  String get semesterWeeks => 'Semaines';

  @override
  String get startTime => 'Heure de début';

  @override
  String get endTime => 'Heure de fin';

  @override
  String get linkedPeriods => 'Créneaux liés';

  @override
  String get linkedPeriodsUnmatched =>
      'Aucun créneau ne correspond à l\'heure actuelle. Touchez pour choisir manuellement.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Période $start-$end';
  }

  @override
  String get teacherName => 'Enseignant';

  @override
  String get credits => 'Crédits';

  @override
  String get remarks => 'Remarques';

  @override
  String get customFields => 'Champs personnalisés';

  @override
  String get customFieldsHint => 'Un par ligne, format : clé:valeur';

  @override
  String get more => 'Plus';

  @override
  String get selectDayOfWeek => 'Choisir un jour';

  @override
  String get selectSemesterWeeks => 'Choisir les semaines';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get clear => 'Effacer';

  @override
  String get confirm => 'Confirmer';

  @override
  String get selectLinkedPeriods => 'Choisir les créneaux liés';

  @override
  String get addCourseTitle => 'Ajouter un cours';

  @override
  String get editCourseTitle => 'Modifier le cours';

  @override
  String get editCourseTooltip => 'Modifier le cours';

  @override
  String get place => 'Lieu';

  @override
  String get time => 'Heure';

  @override
  String get notFilled => 'Non renseigné';

  @override
  String get none => 'Aucun';

  @override
  String get conflictCourses => 'Cours en conflit';

  @override
  String get locationNotFilled => 'Lieu non renseigné';

  @override
  String get setAsDisplayed => 'Définir comme affiché';

  @override
  String get editThisCourse => 'Modifier ce cours';

  @override
  String get settingsTitle => 'Paramètres';

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
      'Aucun emploi du temps n\'est actuellement disponible pour les paramètres.';

  @override
  String get semesterStartDate => 'Date de début du semestre';

  @override
  String get periodTimeSets => 'Jeu d\'horaires des périodes';

  @override
  String get noPeriodTimeAvailable =>
      'Aucun jeu d\'horaires des périodes disponible';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count périodes';
  }

  @override
  String get coursePopupDismissSetting =>
      'Autoriser le toucher à l\'extérieur pour fermer la fenêtre du cours';

  @override
  String get coursePopupDismissSettingHint =>
      'La désactivation désactive aussi la fermeture par glissement vers le bas.';

  @override
  String get preserveTimetableGaps =>
      'Conserver les espaces vides de l\'emploi du temps';

  @override
  String get preserveTimetableGapsHint =>
      'Si désactivé, les pauses déjeuner et autres intervalles sont réduits afin que les cours suivants remontent.';

  @override
  String get showPastEndedCourses => 'Afficher les cours déjà terminés';

  @override
  String get showPastEndedCoursesHint =>
      'Affiche les cours déjà terminés selon la semaine réelle actuelle avec un style gris plus clair.';

  @override
  String get showFutureCourses => 'Afficher les cours futurs';

  @override
  String get showFutureCoursesHint =>
      'Affiche les cours non actifs cette semaine mais prévus pour des semaines ultérieures avec un style gris.';

  @override
  String get timetableDisplaySettings =>
      'Affichage et interactions de l\'emploi du temps';

  @override
  String get timetableDisplaySettingsDesc =>
      'Affichage des cours, disposition, gestes hebdomadaires et ajout rapide';

  @override
  String get showTimetableGridLines =>
      'Afficher les lignes de grille de l\'emploi du temps';

  @override
  String get showTimetableGridLinesHint =>
      'Contrôle la visibilité des lignes de grille horizontales et verticales dans l\'emploi du temps.';

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
  String get liveCourseOutlineColor => 'Couleur du contour du cours';

  @override
  String get liveCourseOutlineColorHint =>
      'Choisissez si les contours ciblent le cours actuel/suivant ou tous les cours affichés sur la page actuelle.';

  @override
  String get liveCourseOutlineSettings => 'Contour du cours';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Définissez si le contour est activé, sa cible, s\'il suit la couleur du thème et sa couleur effective.';

  @override
  String get liveCourseOutlineEnabled => 'Activer le contour';

  @override
  String get liveCourseOutlineFollowTheme => 'Suivre la couleur du thème';

  @override
  String get liveCourseOutlineTarget => 'Cible du contour';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Cours actuel/suivant';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Tous les cours affichés';

  @override
  String get liveCourseOutlineEffectiveColor => 'Couleur effective';

  @override
  String get liveCourseOutlineCustomColor => 'Couleur de contour personnalisée';

  @override
  String get liveCourseOutlineWidth => 'Largeur du contour';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Langue';

  @override
  String get languagePageDescription =>
      'Choisissez l\'une des langues réellement disponibles dans l\'application.';

  @override
  String get languageChinese => 'Chinois';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Réponse API';

  @override
  String get theme => 'Thème';

  @override
  String get themeFollowSystem => 'Suivre le système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeColor => 'Couleur du thème';

  @override
  String get themeColorModeSingle => 'Couleur de thème unique';

  @override
  String get themeColorModeColorful => 'Coloré';

  @override
  String get themeColorUiColors => 'Couleurs de l\'interface';

  @override
  String get themeColorCourseColors => 'Couleurs des cours';

  @override
  String get themeColorPrimary => 'Primaire';

  @override
  String get themeColorSecondary => 'Secondaire';

  @override
  String get themeColorTertiary => 'Tertiaire';

  @override
  String get themeColorCourseText => 'Texte du cours';

  @override
  String get themeColorCourseTextAuto => 'Auto';

  @override
  String get themeColorCourseTextCustom => 'Couleur personnalisée';

  @override
  String get themeColorCourseColorsEmpty =>
      'Les couleurs des cours seront générées après l\'importation d\'un emploi du temps.';

  @override
  String get themeCustomColor => 'Couleur personnalisée';

  @override
  String get themeApplyCustomColor => 'Appliquer la couleur';

  @override
  String get themeApplySettings => 'Appliquer les paramètres';

  @override
  String get dataImportExport => 'Importer et exporter des données';

  @override
  String get dataImportExportDesc =>
      'Importez toutes les données ou un seul emploi du temps, ou exportez l\'emploi du temps actuel/tous les emplois du temps.';

  @override
  String get appBackupTitle => 'Sauvegarde et restauration de l’application';

  @override
  String get appBackupSubtitle =>
      'Sauvegardez ou restaurez les emplois du temps, plannings, paramètres et sites d’école. Les clés API ne sont pas incluses.';

  @override
  String get appBackupSheetSubtitle =>
      'Une restauration complète remplace les données actuelles de l’application. Les clés d’API IA restent dans le stockage sécurisé et ne sont pas écrites dans les fichiers de sauvegarde.';

  @override
  String get restoreBackupFileTitle => 'Restaurer depuis un fichier JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Choisissez un fichier de sauvegarde complet de Sked. Une confirmation sera demandée avant la restauration.';

  @override
  String get restoreBackupTextTitle => 'Coller le JSON de sauvegarde';

  @override
  String get restoreBackupTextSubtitle =>
      'Collez une sauvegarde complète pour restaurer les données actuelles de l’application.';

  @override
  String get shareBackupTitle => 'Partager le fichier de sauvegarde';

  @override
  String get shareBackupSubtitle =>
      'Exportez toutes les données de l’application en JSON. Les clés API sont exclues.';

  @override
  String get saveBackupTitle => 'Enregistrer le fichier de sauvegarde';

  @override
  String get saveBackupSubtitle =>
      'Enregistrez une sauvegarde complète de l’application dans un fichier local.';

  @override
  String get copyBackupTitle => 'Copier le texte de sauvegarde';

  @override
  String get copyBackupSubtitle =>
      'Affiche le JSON complet de la sauvegarde afin de le copier ou de le stocker temporairement.';

  @override
  String get restoreBackupConfirmTitle => 'Restaurer la sauvegarde complète ?';

  @override
  String get restoreBackupConfirmMessage =>
      'Cela remplacera tous les emplois du temps, plannings généraux, paramètres et sites d’école actuels. Les clés API ne sont pas importées depuis les sauvegardes ; saisissez à nouveau la clé avant de parser des emplois du temps.';

  @override
  String get restoreBackupConfirmAction => 'Restaurer la sauvegarde';

  @override
  String get restoreBackupSuccessMessage =>
      'Sauvegarde complète de l’application restaurée. Les clés d’API IA doivent être saisies à nouveau.';

  @override
  String get restoreBackupFailureMessage =>
      'Échec de la restauration. Vérifiez le contenu de la sauvegarde et réessayez.';

  @override
  String get openSourceLicenses => 'Licences open source';

  @override
  String get openSourceLicensesDesc =>
      'Afficher les licences des dépendances Flutter et des ressources d\'icône intégrées.';

  @override
  String get checkForUpdates => 'Rechercher des mises à jour';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Vous utilisez déjà la dernière version ($version)';
  }

  @override
  String get currentVersionLabel => 'Version actuelle';

  @override
  String get newVersionAvailable => 'Mise à jour disponible';

  @override
  String get latestVersionLabel => 'Dernière version';

  @override
  String get updateContentLabel => 'Détails de la mise à jour';

  @override
  String get officialWebsite => 'Site officiel';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Cloud drive';

  @override
  String get ignoreThisVersion => 'Ignorer cette version';

  @override
  String get openUpdatesFailed => 'Impossible d\'ouvrir le lien de mise à jour';

  @override
  String get updateCheckFailedTitle =>
      'Échec de la vérification des mises à jour';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Dépôt GitHub';

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
  String get openGithubFailed => 'Impossible d\'ouvrir le lien du dépôt GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Impossible d\'ouvrir le lien de la politique de confidentialité';

  @override
  String get selectPeriodTimeSet => 'Choisir un jeu d\'horaires des périodes';

  @override
  String get newItem => 'Nouveau';

  @override
  String get editPeriodTimeSet => 'Modifier le jeu d\'horaires des périodes';

  @override
  String get importTimetableFiles => 'Importer un emploi du temps';

  @override
  String get importTimetableFilesDesc =>
      'Prend en charge un ou plusieurs fichiers d\'emploi du temps.';

  @override
  String get importTimetableText =>
      'Importer un emploi du temps depuis du texte';

  @override
  String get importTimetableTextDesc =>
      'Collez le contenu JSON de l\'emploi du temps et importez-le.';

  @override
  String get shareTimetableFiles => 'Partager les fichiers d\'emploi du temps';

  @override
  String get shareTimetableFilesDesc =>
      'Choisissez d\'abord un ou plusieurs emplois du temps.';

  @override
  String get saveTimetableFiles =>
      'Enregistrer les fichiers d\'emploi du temps';

  @override
  String get saveTimetableFilesDesc =>
      'Choisissez d\'abord un ou plusieurs emplois du temps.';

  @override
  String get exportTimetableText => 'Exporter l\'emploi du temps en texte';

  @override
  String get exportTimetableTextDesc =>
      'Choisissez un ou plusieurs emplois du temps, puis copiez le contenu JSON.';

  @override
  String get jsonContent => 'Contenu JSON';

  @override
  String get pasteJsonContentHint => 'Collez le contenu JSON à importer.';

  @override
  String get jsonContentEmpty => 'Collez d\'abord le contenu JSON.';

  @override
  String get copyText => 'Copier';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get share => 'Partager';

  @override
  String get selectTimetablesToExport =>
      'Choisir les emplois du temps à exporter';

  @override
  String get selectTimetablesToImport =>
      'Choisir les emplois du temps à importer';

  @override
  String timetableCourseCount(int count) {
    return '$count cours';
  }

  @override
  String get importAction => 'Importer';

  @override
  String get importTimetableDialogTitle => 'Importer un emploi du temps';

  @override
  String get chooseImportMethod => 'Choisissez la méthode d\'importation.';

  @override
  String get importAsNewTimetable => 'Importer comme nouvel emploi du temps';

  @override
  String get replaceCurrentTimetable => 'Remplacer l\'emploi du temps actuel';

  @override
  String get importPeriodTimeSetDialogTitle =>
      'Importer les jeux d\'horaires des périodes';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Ce fichier contient des jeux d\'horaires des périodes intégrés. Voulez-vous les importer et les associer ?';

  @override
  String get importBundledPeriodTimeSets => 'Importer et associer';

  @override
  String get discardBundledPeriodTimeSets => 'Ignorer les jeux intégrés';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Aucun jeu d\'horaires des périodes existant n\'est disponible ; les jeux intégrés ne peuvent donc pas être ignorés.';

  @override
  String savedToPath(Object path) {
    return 'Enregistré dans $path';
  }

  @override
  String get saveCancelled => 'Enregistrement annulé';

  @override
  String get fileSaveRestrictedTitle => 'Enregistrement de fichier restreint';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Le système n\'a pas pu enregistrer le fichier. Vous pouvez réessayer ou utiliser le partage à la place.';

  @override
  String get retrySave => 'Réessayer l\'enregistrement';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Activez l\'accès aux fichiers dans les paramètres du système, puis revenez et réessayez d\'exporter.';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String get browserDownloadRestrictedTitle =>
      'Téléchargement du navigateur restreint';

  @override
  String get browserDownloadRestrictedMessage =>
      'Ce navigateur ne prend pas en charge l\'enregistrement direct dans un fichier local. Vérifiez les autorisations de téléchargement du navigateur ou utilisez plutôt le partage de fichiers.';

  @override
  String get switchToShare => 'Utiliser le partage à la place';

  @override
  String get fileSaveFailedTitle => 'Échec de l\'enregistrement du fichier';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Impossible d\'écrire dans le chemin actuel. Le dossier cible peut être protégé, le fichier peut être utilisé ou le chemin peut ne pas être accessible en écriture.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Le système n\'a pas pu enregistrer le fichier. Vous pouvez réessayer, vérifier les paramètres du système ou utiliser le partage de fichiers à la place.';

  @override
  String get retryLater => 'Réessayer plus tard';

  @override
  String get exportSwitchedToShare =>
      'Passage au partage de fichiers pour l\'exportation';

  @override
  String get saveFailedRetry =>
      'Échec de l\'enregistrement. Veuillez réessayer plus tard.';

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
  String get appInstanceBlockedTitle => 'Sked est déjà ouvert';

  @override
  String get appInstanceBlockedMessage =>
      'Une autre fenêtre Sked ou un autre onglet du navigateur utilise vos données locales. Fermez cette fenêtre ou cet onglet, puis réessayez.';

  @override
  String get appInstanceLeaseFailedTitle =>
      'Les données locales sont indisponibles';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked n’a pas pu vérifier l’accès exclusif aux données locales. Vos données n’ont été ni ouvertes ni modifiées. Vérifiez l’accès au stockage, puis réessayez.';

  @override
  String get savingChanges => 'Enregistrement des modifications...';

  @override
  String get showApiKey => 'Afficher la clé API';

  @override
  String get hideApiKey => 'Masquer la clé API';

  @override
  String get importFailedCheckContent =>
      'Échec de l\'importation. Veuillez vérifier le contenu du fichier.';

  @override
  String get noImportableTimetables =>
      'Aucun emploi du temps exploitable n\'a été trouvé dans le fichier importé.';

  @override
  String importedTimetablesCount(int count) {
    return '$count emplois du temps importés';
  }

  @override
  String get periodTimesTitle => 'Horaires des périodes';

  @override
  String get importExport => 'Importer et exporter';

  @override
  String get importPeriodTemplate => 'Importer un modèle de périodes';

  @override
  String get importPeriodTemplateText =>
      'Importer un modèle de périodes depuis du texte';

  @override
  String get sharePeriodTemplate => 'Partager le modèle de périodes';

  @override
  String get saveTemplateToFile => 'Enregistrer le modèle dans un fichier';

  @override
  String get exportPeriodTemplateText =>
      'Exporter le modèle de périodes en texte';

  @override
  String get deletePeriodTimeSet => 'Supprimer le jeu d\'horaires des périodes';

  @override
  String get periodTimeSetName => 'Nom du jeu d\'horaires des périodes';

  @override
  String get addOnePeriod => 'Ajouter une période';

  @override
  String periodNumberLabel(int index) {
    return 'Période $index';
  }

  @override
  String get deleteThisPeriod => 'Supprimer cette période';

  @override
  String durationMinutes(int minutes) {
    return 'Durée $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Intervalle depuis la précédente : $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'L\'heure de fin doit être postérieure à l\'heure de début';

  @override
  String get periodOverlapPrevious => 'Cette période chevauche la précédente';

  @override
  String get periodTimesSaved => 'Horaires des périodes enregistrés';

  @override
  String get deletePeriodTimeSetTitle =>
      'Supprimer le jeu d\'horaires des périodes';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Supprimer \"$name\" ?';
  }

  @override
  String get currentPeriodTimeSet => 'jeu d\'horaires des périodes actuel';

  @override
  String importedPeriodTimesCount(int count) {
    return '$count horaires des périodes importés';
  }

  @override
  String get periodFilePermissionTitle => 'Autorisation de fichier requise';

  @override
  String get androidFilePermissionMessage =>
      'L\'exportation Android nécessite l\'autorisation d\'accès aux fichiers. Accordez-la pour continuer l\'enregistrement.';

  @override
  String get reauthorize => 'Autoriser à nouveau';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Autorisation refusée définitivement';

  @override
  String get permissionSettingsExportMessage =>
      'Activez l\'accès aux fichiers dans les paramètres du système, puis revenez et réessayez d\'exporter.';

  @override
  String get privacyPolicyTitle => 'Politique de confidentialité';

  @override
  String get privacyPolicyEntryDesc =>
      'Découvrez comment l\'application gère le stockage local, la configuration des sites scolaires, l\'import/export de fichiers, l\'analyse de pages web et les liens externes.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Version acceptée : $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked est un outil d\'emploi du temps qui privilégie le stockage local. Les emplois du temps, les jeux d\'horaires des périodes et la configuration des sites scolaires sont stockés uniquement sur votre appareil ou dans votre navigateur et ne sont jamais téléversés automatiquement. L\'application ne traite les données que lorsque vous déclenchez explicitement des actions comme l\'importation, l\'analyse de pages web, le partage ou l\'ouverture de liens externes. La politique de confidentialité complète est disponible en ligne.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Stockage local';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Importation et exportation';

  @override
  String get privacyPolicyImportExportBody =>
      'L\'application lit ou écrit des fichiers JSON d\'emploi du temps, des fichiers JSON de sites scolaires et des fichiers de modèle de périodes uniquement lorsque vous choisissez explicitement un fichier ou lancez une action d\'exportation. L\'importation de ces fichiers reste une opération locale, sauf si vous choisissez également l\'analyse de pages web. La récupération d\'une liste de modèles personnalisés est aussi une action réseau explicite et ne contacte que le point de terminaison personnalisé que vous avez configuré.';

  @override
  String get privacyPolicySharingTitle => 'Partage';

  @override
  String get privacyPolicySharingBody =>
      'Lorsque vous utilisez explicitement le partage, l\'application transmet le fichier exporté à la feuille de partage du système ou à l\'application cible que vous choisissez. La façon dont ce fichier est ensuite traité dépend de l\'application ou du service cible sélectionné.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Liens externes';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Lorsque vous ouvrez des liens externes tels que le dépôt GitHub, l\'application transmet l\'action à votre navigateur ou à une autre application externe. Le traitement des données à partir de ce moment est régi par le tiers que vous ouvrez.';

  @override
  String get privacyPolicyNoCollectionTitle =>
      'Ce que l\'application ne collecte pas';

  @override
  String get privacyPolicyNoCollectionBody =>
      'L\'application n\'exige pas de compte Sked et n\'active ni analytics, ni identifiants publicitaires, ni sauvegarde cloud. Elle ne fournit pas non plus de champ dédié à la collecte des mots de passe des comptes scolaires. Si vous vous connectez à un site scolaire dans l\'application, cette interaction se produit sur la page scolaire que vous avez ouverte.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Analyse de pages web';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Lorsque vous utilisez l’import d’une page web d’école ou l’analyse d’un texte d’emploi du temps / HTML collé, l’application prépare et nettoie d’abord le contenu localement, puis envoie le texte d’emploi du temps, le texte de page ou le contenu HTML soumis, le titre et l’URL facultatifs de la page, la langue actuelle de l’application et le contenu du prompt d’analyse au point de terminaison compatible OpenAI que vous avez configuré. La récupération de la liste des modèles interroge aussi ce même point de terminaison. Sked ne fournit pas de point de terminaison d’analyse intégré et n’envoie pas les requêtes d’analyse à un backend d’analyse d’emploi du temps contrôlé par le développeur. Le point de terminaison personnalisé et les éventuels services en amont peuvent stocker, transférer, limiter, supprimer ou traiter les données d’une autre manière selon les règles du fournisseur de services que vous choisissez. Si vous utilisez une Base URL en http://, utilisez-la uniquement sur des appareils, réseaux et services de point de terminaison de confiance, car le contenu et les clés API peuvent ne pas être protégés par le chiffrement du transport.';

  @override
  String get privacyPolicyUpdatesTitle => 'Mises à jour de la politique';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'La version actuelle de la politique de confidentialité est $version. Si une version ultérieure modifie la manière dont les données sont traitées, l\'application peut vous demander de relire et d\'accepter la politique mise à jour.';
  }

  @override
  String get privacyGateTitle =>
      'Veuillez accepter la politique de confidentialité avant d\'utiliser l\'application';

  @override
  String get privacyGateSummaryStorage =>
      'Les emplois du temps, les jeux d\'horaires des périodes et la configuration des sites scolaires sont stockés uniquement en local et ne sont pas automatiquement téléversés vers un serveur du développeur.';

  @override
  String get privacyGateSummaryImportExport =>
      'L\'importation, l\'exportation et le partage ne se produisent que lorsque vous les lancez explicitement ; l\'analyse de pages web envoie uniquement le contenu compressé que vous soumettez au point de terminaison configuré, et vous pouvez vérifier l\'emploi du temps analysé avant de l\'enregistrer.';

  @override
  String get privacyGateSummaryUpdates =>
      'Si une version ultérieure modifie la manière dont les données sont traitées, l\'application peut vous demander de revoir à nouveau la politique de confidentialité mise à jour.';

  @override
  String get schoolWebImportEntry =>
      'Importer depuis la page web de l\'établissement';

  @override
  String get schoolWebImportEntryDesc =>
      'Importer la page d\'emploi du temps actuelle depuis le site de l\'établissement.';

  @override
  String get schoolSitesManageEntry => 'Gérer les sites scolaires';

  @override
  String get schoolSitesManageEntryDesc =>
      'Ajouter, modifier et supprimer des URL de connexion scolaire, avec import/export JSON.';

  @override
  String get schoolSitesPageTitle => 'Gestion des sites scolaires';

  @override
  String get schoolSitesImportJson => 'Importer le JSON des écoles';

  @override
  String get schoolSitesShareJson => 'Partager le JSON des écoles';

  @override
  String get schoolSitesSaveJson => 'Enregistrer le JSON des écoles';

  @override
  String get schoolSitesSaved => 'Sites scolaires enregistrés';

  @override
  String get schoolSitesImported => 'Sites scolaires importés';

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
      'Aucune configuration de site scolaire pour le moment.';

  @override
  String get schoolSitesNameLabel => 'Nom de l\'établissement';

  @override
  String get schoolSitesLoginUrlLabel => 'URL de connexion';

  @override
  String get schoolSitesAdd => 'Ajouter un établissement';

  @override
  String get schoolSitesEdit => 'Modifier l\'établissement';

  @override
  String get schoolSitesDeleteTitle => 'Supprimer l\'établissement';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Supprimer \"$name\" ?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Renseignez d\'abord le nom de l\'établissement et l\'URL de connexion.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Importer en collant le contenu de la page d\'emploi du temps';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Collez manuellement le code source ou le contenu brut de la page contenant les informations d\'emploi du temps.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Analyser l\'emploi du temps depuis le contenu de la page';

  @override
  String get schoolHtmlImportUrlLabel => 'URL source (facultatif)';

  @override
  String get schoolHtmlImportTitleLabel => 'Titre de la page (facultatif)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Contenu de la page';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Collez ici le code source ou le contenu brut de la page contenant les informations d\'emploi du temps.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Tout contenu contenant des informations d\'emploi du temps peut être analysé et importé, pas seulement du HTML.';

  @override
  String get schoolHtmlImportCompress => 'Préparer le contenu';

  @override
  String get schoolHtmlImportCompressed => 'Contenu préparé';

  @override
  String get schoolHtmlImportCompressFirst =>
      'Préparez le contenu avant de continuer.';

  @override
  String get schoolHtmlImportSubmit => 'Analyser et importer';

  @override
  String get schoolImportContentTruncated =>
      'Cette page a atteint la limite d’importation sécurisée. Seule la partie capturée sera envoyée pour analyse.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'L\'analyse peut prendre un moment. Veuillez patienter.';

  @override
  String get schoolHtmlImportEmpty => 'Collez d\'abord le HTML de la page.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Retour à la page web';

  @override
  String get schoolWebImportPageTitle =>
      'Importation depuis la page web scolaire';

  @override
  String get schoolWebImportPreview => 'Aperçu de l\'importation';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count cours';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count périodes';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Titre de la page';

  @override
  String get schoolWebImportParserUsed => 'Analyseur';

  @override
  String get schoolWebImportWarnings => 'Notes d\'importation';

  @override
  String get schoolWebImportParserDetails => 'Détails de l\'analyse';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Développer les détails de l\'analyse';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Réduire les détails de l\'analyse';

  @override
  String get schoolWebImportOpenPageHint =>
      'Connectez-vous au site scolaire dans l\'application, puis accédez manuellement à la page d\'emploi du temps.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Cette plateforme ne prend pas encore en charge la connexion web intégrée. Veuillez utiliser une plateforme compatible WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Choisir un établissement';

  @override
  String get schoolWebImportNoSchools =>
      'Aucune configuration d\'établissement n\'est disponible. Vérifiez d\'abord school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Échec du chargement de la configuration de l\'établissement. Vérifiez le format du fichier JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importer la page actuelle';

  @override
  String get schoolWebImportLoadingPage => 'Chargement de la page…';

  @override
  String get schoolWebImportParsing => 'Analyse de la page actuelle…';

  @override
  String get schoolWebImportLoadFailed =>
      'Échec du chargement de la page. Veuillez actualiser ou réessayer plus tard.';

  @override
  String get schoolWebImportUnknownOrigin => 'Site inconnu';

  @override
  String get schoolWebImportExitTitle => 'Quitter le navigateur ?';

  @override
  String get schoolWebImportExitMessage =>
      'La page va se fermer. Tout ce que vous n\'avez pas encore importé sera perdu.';

  @override
  String get schoolWebImportExitConfirm => 'Quitter';

  @override
  String get schoolWebImportEmptyPage =>
      'Le contenu actuel de la page est vide et ne peut pas encore être importé.';

  @override
  String get schoolWebImportSuccess => 'Emploi du temps web importé';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Source de l\'analyseur';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Compatible OpenAI personnalisé';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Analyseur personnalisé compatible OpenAI';

  @override
  String get schoolImportParserCustomPromptTitle => 'Prompt personnalisé';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Modifiez ici le prompt intégré de l\'analyseur. Les changements n\'affectent que l\'analyseur personnalisé compatible OpenAI.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Le prompt intégré est chargé ici par défaut. Supprimez-le pour revenir à la version intégrée.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Rétablir le prompt par défaut';

  @override
  String get schoolImportParserBaseUrl => 'Base URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'La Base URL doit être une URL HTTP ou HTTPS avec un hôte.';

  @override
  String get schoolImportParserApiKey => 'API key';

  @override
  String get schoolImportParserModel => 'Modèle';

  @override
  String get schoolImportParserFetchModels => 'Récupérer la liste des modèles';

  @override
  String get schoolImportParserFetchingModels => 'Récupération des modèles...';

  @override
  String get schoolImportParserNoModelsFound =>
      'Aucun modèle n\'a été renvoyé par le point de terminaison.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Impossible de récupérer les modèles. Vérifiez le point de terminaison et réessayez.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return '$count modèles récupérés';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Utiliser un point de terminaison HTTP non chiffré ?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'La clé API et le contenu de l’emploi du temps peuvent être lus ou modifiés pendant le transfert. Continuez uniquement si vous faites confiance à cet appareil, à ce réseau et à ce point de terminaison. Cette autorisation reste valable jusqu’à la fermeture de Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'La configuration de l\'analyseur personnalisé est incomplète. Renseignez d\'abord la Base URL, l\'API key et le modèle.';

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
    return 'Analyseur : Personnalisé ($model)';
  }

  @override
  String get privacyViewFullPolicy =>
      'Voir la politique de confidentialité complète';

  @override
  String get privacyAgreeAndContinue => 'Accepter et continuer';

  @override
  String get privacyDecline => 'Refuser';

  @override
  String get privacyDeclineWebHint =>
      'Cet environnement de navigateur ne permet pas à l\'application de fermer la page pour vous. Si vous n\'acceptez pas, veuillez fermer vous-même cet onglet ou cette fenêtre.';

  @override
  String get defaultPeriodTimeSetName => 'Périodes par défaut';

  @override
  String get periodTimeSetFallbackName => 'Horaires des périodes';

  @override
  String get untitledTimetableName => 'Emploi du temps sans titre';

  @override
  String get newTimetableName => 'Nouvel emploi du temps';

  @override
  String get newPeriodTimeSetName => 'Nouveau jeu d\'horaires des périodes';

  @override
  String get emptyTimetableName => 'Emploi du temps vide';

  @override
  String importedPeriodTimeSetName(Object name) {
    return 'Périodes de $name';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Le type du fichier importé ne correspond pas.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Cette version du fichier importé n\'est pas encore prise en charge.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Aucun horaire des périodes trouvé dans le fichier importé.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Veuillez sélectionner au moins un emploi du temps.';

  @override
  String get noExportableTimetableMessage =>
      'Aucun emploi du temps n\'est disponible pour l\'exportation.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Le remplacement de l\'emploi du temps actuel ne permet de sélectionner qu\'un seul emploi du temps.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Aucun emploi du temps actuel à remplacer.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Ce jeu d\'horaires des périodes est encore utilisé par $count emploi(s) du temps. Réaffectez-les avant de le supprimer.';
  }

  @override
  String get weekdayMonday => 'Lundi';

  @override
  String get weekdayTuesday => 'Mardi';

  @override
  String get weekdayWednesday => 'Mercredi';

  @override
  String get weekdayThursday => 'Jeudi';

  @override
  String get weekdayFriday => 'Vendredi';

  @override
  String get weekdaySaturday => 'Samedi';

  @override
  String get weekdaySunday => 'Dimanche';

  @override
  String get weekdayShortMonday => 'Lun';

  @override
  String get weekdayShortTuesday => 'Mar';

  @override
  String get weekdayShortWednesday => 'Mer';

  @override
  String get weekdayShortThursday => 'Jeu';

  @override
  String get weekdayShortFriday => 'Ven';

  @override
  String get weekdayShortSaturday => 'Sam';

  @override
  String get weekdayShortSunday => 'Dim';

  @override
  String get monthJanuary => 'Jan';

  @override
  String get monthFebruary => 'Fév';

  @override
  String get monthMarch => 'Mar';

  @override
  String get monthApril => 'Avr';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJune => 'Juin';

  @override
  String get monthJuly => 'Juil';

  @override
  String get monthAugust => 'Aoû';

  @override
  String get monthSeptember => 'Sep';

  @override
  String get monthOctober => 'Oct';

  @override
  String get monthNovember => 'Nov';

  @override
  String get monthDecember => 'Déc';

  @override
  String get semesterWeeksWholeTerm => 'Tout le semestre';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Semaines $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Semaines $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Choisissez votre mode de départ';

  @override
  String get firstLaunchSubtitle =>
      'Choisissez l’espace de travail que vous utilisez le plus. Vous pourrez changer de mode plus tard.';

  @override
  String get firstLaunchStudentDesc =>
      'Gérez les emplois du temps, cours, semaines, horaires de périodes et imports.';

  @override
  String get firstLaunchGeneralDesc =>
      'Gérez les catégories, événements, rappels et données JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Commencer avec l’emploi du temps';

  @override
  String get firstLaunchStartGeneral => 'Commencer avec le planning';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'En choisissant un espace de travail de départ, vous confirmez avoir lu et accepté la ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Politique de confidentialité';

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
  String get today => 'Aujourd’hui';

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
      'Vues, barre d’outils, format de date et ajout rapide';

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
  String get viewWeek => 'Semaine';

  @override
  String get viewDay => 'Jour';

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
  String get developerModeTitle => 'Mode développeur';

  @override
  String get developerModeDescription =>
      'Outils permettant d’ajouter des données d’exemple complètes pour vérifier l’interface et les interactions.';

  @override
  String get developerSampleLanguage => 'Langue des données d’exemple';

  @override
  String get developerSampleChinese => 'Chinois';

  @override
  String get developerSampleEnglish => 'Anglais';

  @override
  String get developerSampleDataDescription =>
      'Ajoute un emploi du temps ainsi que des catégories et événements sans remplacer les données existantes.';

  @override
  String get developerAddSampleData => 'Ajouter des données d’exemple';

  @override
  String get developerSampleDataAdded =>
      'L’emploi du temps et les événements d’exemple ont été ajoutés.';

  @override
  String get developerModeLongPressHint =>
      'Appuyez pendant 3 secondes pour ouvrir le mode développeur';

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
  String get developerNotificationExactAlarmBlocked => 'Not allowed';

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
  String get developerNotificationReconcileResultBlocked =>
      'Blocked until all precise-delivery conditions are met';

  @override
  String get developerNotificationReconcileResultFailed => 'Failed';

  @override
  String get developerNotificationBackgroundLimits =>
      'Vendor background limits';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Vendor background restrictions may affect delivery.';

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
  String get collapseWorkspaceNavigation =>
      'Réduire la navigation de l’espace de travail';

  @override
  String get expandWorkspaceNavigation =>
      'Développer la navigation de l’espace de travail';

  @override
  String get schoolWebImportExitBrowser => 'Quitter le navigateur intégré';

  @override
  String get schoolWebImportEditAddress => 'Modifier l’adresse';

  @override
  String get schoolWebImportAddressLabel => 'Adresse web';

  @override
  String get schoolWebImportOpenAddress => 'Ouvrir';

  @override
  String get schoolWebImportAddressInvalid =>
      'Saisissez une adresse HTTP ou HTTPS avec un hôte.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Cette page web a demandé une nouvelle fenêtre qui ne peut pas s’ouvrir sur cet appareil.';

  @override
  String get schoolWebImportSecureConnection => 'Connexion sécurisée';

  @override
  String get schoolWebImportInsecureConnection => 'Connexion non sécurisée';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Ouvrir la connexion à l’établissement ?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'La connexion à l’établissement peut envoyer des identifiants au moyen de formulaires ou de redirections du serveur vers l’établissement et ses fournisseurs de connexion. Android ne peut pas interrompre chaque transfert de ce type pour demander une confirmation distincte de la destination. Continuez uniquement si vous leur faites confiance pour cette session d’importation :\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Ouvrir une connexion scolaire non sécurisée ?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Cette connexion scolaire utilise HTTP. Toute personne capable d’observer ou de modifier cette connexion peut lire ou changer vos identifiants et le contenu de la page. Continuez uniquement si vous acceptez ce risque pour :\n\n$origin';
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
  String get notificationPrecisionLimitations =>
      'Android cannot provide mathematical absolute precision. Shutdowns, system time changes, crashes, and vendor firmware restrictions can still delay delivery.';

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
  String get notificationBatteryOptimization => 'Battery optimization';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Android battery optimization allowlisted';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Precise reminders require the Android battery-optimization allowlist';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Open battery optimization settings';

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
