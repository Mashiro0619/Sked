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
  String get schoolImportExpandWarnings =>
      'Afficher les remarques d’importation';

  @override
  String get schoolImportCollapseWarnings =>
      'Masquer les remarques d’importation';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Certains cours ont encore lieu en semaine $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Remplacer l’emploi du temps actuel ?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'L’emploi du temps importé remplacera l’emploi du temps actuel.';

  @override
  String get createTimetable => 'Nouvel emploi du temps';

  @override
  String get jumpToWeek => 'Aller à la semaine';

  @override
  String get timetable => 'Emploi du temps';

  @override
  String get themeWorkspaceSchedule => 'Agenda';

  @override
  String get timetableName => 'Nom de l\'emploi du temps';

  @override
  String get timetableNameRequired => 'Saisissez le nom de l’emploi du temps';

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
  String get settingsSectionTimetable => 'Emploi du temps';

  @override
  String get settingsSectionGeneralSchedule => 'Agenda';

  @override
  String get settingsSectionAppearance => 'Apparence';

  @override
  String get settingsSectionApp => 'Application';

  @override
  String get settingsSectionWorkspace => 'Espace de travail';

  @override
  String get settingsSectionAppearanceLanguage => 'Apparence et langue';

  @override
  String get settingsSectionDataSecurity => 'Données et sécurité';

  @override
  String get settingsSectionAbout => 'À propos de Sked';

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
      'Disposition horizontale et gestes';

  @override
  String get fitDaySelectorToWidth => 'Adapter le sélecteur de jours à l’écran';

  @override
  String get fitDaySelectorToWidthHint =>
      'Affiche les sept jours à l’écran si possible. Désactivez cette option pour utiliser une largeur fixe et faire défiler les jours.';

  @override
  String get fitWeekColumnsToWidth =>
      'Adapter les colonnes de la semaine à l’écran';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Affiche les sept colonnes de l’emploi du temps à l’écran si possible. Désactivez cette option pour utiliser une largeur fixe et faire défiler les colonnes.';

  @override
  String get enableWeekSwipeNavigation => 'Balayer pour changer de semaine';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Balayez vers la gauche ou la droite pour changer de semaine. Avec des largeurs fixes, faites d’abord glisser au-delà du bord.';

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
  String get microsoftStoreUpdates =>
      'Les mises à jour sont gérées par le Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Recevoir les préversions';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Inclure les versions Alpha, Beta et RC, qui peuvent être instables. Sinon, seules les versions stables sont proposées.';

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
  String get cloudDrive => 'Stockage en ligne';

  @override
  String get ignoreThisVersion => 'Ignorer cette version';

  @override
  String get openUpdatesFailed => 'Impossible d\'ouvrir le lien de mise à jour';

  @override
  String get updateCheckFailedTitle =>
      'Échec de la vérification des mises à jour';

  @override
  String get updateCheckFailedMessage =>
      'Impossible de récupérer la dernière version depuis GitHub. Vous pouvez toujours ouvrir la page des versions GitHub ci-dessous.';

  @override
  String get githubRepository => 'Dépôt GitHub';

  @override
  String get googlePlayStoreDesc => 'Voir Sked sur Google Play';

  @override
  String get openGooglePlayFailed => 'Impossible d’ouvrir Google Play';

  @override
  String get starSkedOnGithub => 'Ajoutez une étoile à Sked sur GitHub !';

  @override
  String get starSkedOnGithubDesc =>
      'Ouvrez le dépôt du projet et attribuez une étoile à Sked';

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
  String get periodTimesUnsavedExitTitle => 'Modifications non enregistrées';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Les dernières modifications des horaires n’ont pas pu être enregistrées. Vous pouvez réessayer, continuer à les modifier ou les abandonner.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Certains horaires sont invalides. Corrigez-les avant d’enregistrer ou abandonnez les modifications et quittez cette page.';

  @override
  String get discardChangesAndExit => 'Abandonner et quitter';

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
      'Sur les plateformes natives, Sked enregistre les emplois du temps, les agendas, les réglages associés et la configuration modifiable des sites scolaires dans le dossier de données de l’application prévu par le système d’exploitation. La version Web utilise le stockage du navigateur. Les fichiers créés par les anciennes versions dans le dossier Documents de l’utilisateur restent en place, mais ne sont ni lus ni migrés automatiquement. Pour conserver ces données, exportez une sauvegarde complète depuis l’ancienne version avant la mise à jour, puis restaurez-la ensuite. Les réglages de l’API d’IA sont enregistrés localement ; la clé API personnalisée est conservée dans le stockage sécurisé de la plateforme lorsqu’il est disponible. Les sauvegardes complètes de l’application ne contiennent pas la clé API personnalisée. L’application ne transfère pas automatiquement ces données locales vers un serveur contrôlé par le développeur.';

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
  String get schoolSitesImportPreviewTitle =>
      'Vérifier l’importation des sites scolaires';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount sites valides, $invalidCount entrées invalides.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Le fichier contient une liste vide de sites scolaires.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'L’entrée $position est invalide et sera ignorée.';
  }

  @override
  String get schoolSitesImportMerge => 'Fusionner';

  @override
  String get schoolSitesImportReplace => 'Remplacer';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Remplacer les sites scolaires actuels ?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Cette opération supprime les $currentCount sites actuels et enregistre les $importedCount sites importés. Elle est irréversible.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Les données des sites scolaires doivent être restaurées';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked n’a pu lire ni le fichier des sites scolaires ni sa sauvegarde. Des copies protégées ont été créées avant le blocage des écritures.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Le stockage des sites scolaires est indisponible';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked ne peut pas accéder au stockage des sites scolaires pour le moment. Vérifiez l’accès au stockage et la disponibilité de l’appareil, puis réessayez. Les données actuelles des sites ne seront pas écrasées.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Les fichiers de récupération et les emplacements de stockage concernés figurent ci-dessous. Ne modifiez aucun fichier tant que la liste des sites n’a pas été restaurée.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Repartir sans sites scolaires';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Repartir avec une liste vide de sites scolaires ?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Les copies protégées seront conservées, mais Sked créera un nouveau fichier de sites scolaires vide. Continuez uniquement si vous ne souhaitez pas d’abord réessayer la récupération.';

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
      'La configuration de l’analyseur personnalisé est incomplète. Renseignez d’abord l’URL de base, la clé API et le modèle.';

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
  String get schoolImportParserSettingsTitle =>
      'API d’import d’emploi du temps';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configurez l’API compatible OpenAI pour importer les emplois du temps, et non pour un assistant de conversation.';

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
  String get schoolImportParserBaseUrl => 'URL de base';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'La Base URL doit être une URL HTTP ou HTTPS avec un hôte.';

  @override
  String get schoolImportParserApiKey => 'Clé API';

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
      'La clé API personnalisée est conservée dans le stockage sécurisé de la plateforme lorsqu’il est disponible. Utilisez des identifiants d’analyseur personnalisés et des points d’accès HTTP uniquement sur des appareils, dans des navigateurs et sur des réseaux de confiance.';

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
  String get clearAppData => 'Effacer les données';

  @override
  String get clearAppDataDesc =>
      'Supprimer définitivement toutes les données locales de Sked et quitter l’application';

  @override
  String get clearAppDataConfirmTitle => 'Effacer toutes les données de Sked ?';

  @override
  String get clearAppDataConfirmMessage =>
      'Cette opération supprime définitivement les emplois du temps, les agendas, les réglages, les sites scolaires, les sauvegardes locales, les copies de récupération et la clé API d’IA, puis ferme Sked. Les fichiers exportés ailleurs ne sont pas supprimés. Cette opération est irréversible.';

  @override
  String get clearAppDataAction => 'Effacer les données et quitter';

  @override
  String get clearAppDataFailed =>
      'Impossible d’effacer toutes les données locales. Sked reste ouvert pour vous permettre de réessayer.';

  @override
  String get clearAppDataExitFailed =>
      'Les données locales ont été effacées, mais Sked n’a pas pu se fermer. Fermez l’application manuellement avant de la réutiliser.';

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
  String get generalSchedule => 'Agenda';

  @override
  String get studentTimetable => 'Emploi du temps';

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
  String get switchMode => 'Changer de mode';

  @override
  String get generalScheduleComingSoon => 'L’agenda sera bientôt disponible';

  @override
  String get switchToStudentTimetable => 'Passer à l’emploi du temps';

  @override
  String get mySchedule => 'Mon agenda';

  @override
  String get today => 'Aujourd’hui';

  @override
  String get addEvent => 'Ajouter un événement';

  @override
  String get editEvent => 'Modifier l’événement';

  @override
  String get eventTitle => 'Titre';

  @override
  String get eventTitleRequired => 'Saisissez un titre';

  @override
  String get eventStartTime => 'Heure de début';

  @override
  String get eventEndTime => 'Heure de fin';

  @override
  String get eventDate => 'Date';

  @override
  String get eventTime => 'Heure';

  @override
  String get eventNotes => 'Notes';

  @override
  String get eventColor => 'Couleur';

  @override
  String get eventRecurrence => 'Répétition';

  @override
  String get recurrenceNone => 'Ne se répète pas';

  @override
  String get recurrenceWeekly => 'Chaque semaine';

  @override
  String get recurrenceEndDate => 'Date de fin';

  @override
  String get recurrenceNoEndDate => 'Sans date de fin';

  @override
  String get recurrenceSetEndDate => 'Définir';

  @override
  String get recurrenceChangeEndDate => 'Modifier';

  @override
  String get repeatsWeekly => 'Se répète chaque semaine';

  @override
  String recurrenceUntil(Object date) {
    return 'Jusqu’au $date';
  }

  @override
  String get switchToGeneralSchedule => 'Passer à l’agenda';

  @override
  String get generalDisplaySettings => 'Réglages généraux d’affichage';

  @override
  String get generalDisplaySettingsDesc =>
      'Vues, barre d’outils, format de date et ajout rapide';

  @override
  String get closePopupOnOutsideTap =>
      'Fermer la fenêtre en appuyant à l’extérieur';

  @override
  String get showGridLines => 'Afficher les lignes de la grille';

  @override
  String get generalScheduleImportExport =>
      'Importer et exporter des catégories';

  @override
  String get generalScheduleImportExportDesc =>
      'Importer ou partager des catégories de l’agenda';

  @override
  String get importGeneralSchedules => 'Importer des catégories';

  @override
  String get importGeneralSchedulesDesc =>
      'Lire les catégories d’un fichier JSON';

  @override
  String get shareGeneralSchedules => 'Partager des catégories';

  @override
  String get shareGeneralSchedulesDesc =>
      'Partager des catégories sous forme de fichier JSON';

  @override
  String get saveGeneralSchedules => 'Enregistrer les catégories';

  @override
  String get saveGeneralSchedulesDesc =>
      'Enregistrer des catégories dans un fichier JSON';

  @override
  String get selectSchedulesToExport =>
      'Sélectionner les catégories à exporter';

  @override
  String get selectSchedulesToImport =>
      'Sélectionner les catégories à importer';

  @override
  String generalScheduleEventCount(int count) {
    return 'Événements : $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return '$count catégories importées';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Ajouter le contenu importé comme nouvelle catégorie ou remplacer une catégorie existante ?';

  @override
  String get addAsNewSchedule => 'Ajouter comme nouvelle catégorie';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Sélectionnez au moins une catégorie.';

  @override
  String get noExportableScheduleMessage => 'Aucune catégorie à exporter.';

  @override
  String get noSchedulesInImportMessage =>
      'Le fichier importé ne contient aucune catégorie.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Choisissez exactement une catégorie importée pour le remplacement.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'La catégorie sélectionnée pour le remplacement est indisponible.';

  @override
  String get calendars => 'Catégories';

  @override
  String get calendar => 'Catégorie';

  @override
  String get viewWeek => 'Semaine';

  @override
  String get viewDay => 'Jour';

  @override
  String get viewList => 'Liste';

  @override
  String get viewMonth => 'Mois';

  @override
  String visibleCategoryCount(int count) {
    return '$count catégories';
  }

  @override
  String get noVisibleCategories => 'Aucune catégorie visible';

  @override
  String get selectCategoryToReplace => 'Choisir la catégorie à remplacer';

  @override
  String get replaceCategory => 'Remplacer la catégorie';

  @override
  String get deleteEventTitle => 'Supprimer l’événement';

  @override
  String get deleteEventConfirmation =>
      'Cet événement sera définitivement supprimé.';

  @override
  String get deleteRecurringEventTitle => 'Supprimer l’événement récurrent';

  @override
  String get eventDuplicated => 'Événement dupliqué';

  @override
  String get searchEvents => 'Rechercher des événements';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get filterByColor => 'Filtrer par couleur';

  @override
  String get allColors => 'Toutes les couleurs';

  @override
  String upcomingEventsCount(int count) {
    return 'À venir : $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'En retard : $count';
  }

  @override
  String get allDay => 'Toute la journée';

  @override
  String get collapseAllDayTimeline =>
      'Réduire les événements sur toute la journée';

  @override
  String get expandAllDayTimeline =>
      'Développer les événements sur toute la journée';

  @override
  String allDayEventsCount(int count) {
    return '$count événements sur toute la journée';
  }

  @override
  String moreEvents(int count) {
    return '+$count autres';
  }

  @override
  String get noMatchingEvents => 'Aucun événement correspondant';

  @override
  String get noUpcomingEvents => 'Aucun événement à venir';

  @override
  String get addCalendar => 'Ajouter une catégorie';

  @override
  String get newCalendar => 'Nouvelle catégorie';

  @override
  String get hideCalendar => 'Masquer la catégorie';

  @override
  String get showCalendar => 'Afficher la catégorie';

  @override
  String get rename => 'Renommer';

  @override
  String get renameCalendar => 'Renommer la catégorie';

  @override
  String get name => 'Nom';

  @override
  String get deleteCalendar => 'Supprimer la catégorie';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteThisOccurrence => 'Supprimer cette occurrence';

  @override
  String get deleteFutureOccurrences =>
      'Supprimer cette occurrence et les suivantes';

  @override
  String get deleteAllOccurrences => 'Supprimer toute la série';

  @override
  String get duplicateEvent => 'Dupliquer';

  @override
  String get repeatsDaily => 'Se répète chaque jour';

  @override
  String get repeatsMonthly => 'Se répète chaque mois';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Se répète tous les $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count fois';
  }

  @override
  String get recurrenceDaily => 'Chaque jour';

  @override
  String get recurrenceMonthly => 'Chaque mois';

  @override
  String get recurrenceCustom => 'Personnalisée';

  @override
  String get recurrenceEvery => 'Tous les';

  @override
  String get recurrenceUnit => 'Unité';

  @override
  String get recurrenceDays => 'Jours';

  @override
  String get recurrenceWeeks => 'Semaines';

  @override
  String get recurrenceMonths => 'Mois';

  @override
  String get recurrenceRepeatCount => 'Nombre de répétitions';

  @override
  String get recurrenceNoLimit => 'Sans limite';

  @override
  String get recurrencePositiveNumber => 'Saisissez un nombre positif';

  @override
  String get clearEndDate => 'Effacer la date de fin';

  @override
  String get pickDate => 'Choisir une date';

  @override
  String get pickTime => 'Choisir une heure';

  @override
  String get reminder => 'Rappel dans l’application';

  @override
  String get reminderAtStart => 'Au début';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min avant';
  }

  @override
  String get reminderHourBefore => '1 heure avant';

  @override
  String get reminderDayBefore => '1 jour avant';

  @override
  String get markReminderHandled => 'Marquer comme traité';

  @override
  String get restoreReminder => 'Rétablir le rappel dans l’application';

  @override
  String get reminderHandled => 'Rappel dans l’application marqué comme traité';

  @override
  String get reminderRestored => 'Rappel dans l’application rétabli';

  @override
  String get reminderUpcoming => 'À venir';

  @override
  String get reminderOverdue => 'En retard';

  @override
  String get generalFitWeekColumnsToWidth => 'Adapter la semaine à l’écran';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Affiche toute la semaine dans les mises en page compactes. Désactivez pour défiler horizontalement. Les plages personnalisées de plus de 7 jours restent défilantes.';

  @override
  String get showWeekends => 'Afficher les week-ends';

  @override
  String get startHour => 'Heure de début';

  @override
  String get endHour => 'Heure de fin';

  @override
  String get timeGridDensity => 'Densité de la grille horaire';

  @override
  String get timeGridHourHeight => 'Hauteur d’une ligne d’heure';

  @override
  String get timeGridHourHeightHint =>
      'Ajuste l’échelle verticale des vues Jour et Semaine sans modifier l’intervalle de 15, 30 ou 60 minutes de la grille.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Importer un fichier JSON';

  @override
  String get pasteJson => 'Coller du JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Importer des catégories à partir de JSON copié';

  @override
  String get importIcsFile => 'Importer un fichier ICS';

  @override
  String get importIcsFileDesc =>
      'Lire les événements d’un fichier calendrier .ics';

  @override
  String get pasteIcs => 'Coller du contenu ICS';

  @override
  String get pasteIcsDesc =>
      'Importer des événements à partir de texte de calendrier copié';

  @override
  String get copyJson => 'Copier le JSON';

  @override
  String get copyJsonDesc =>
      'Copier les catégories sélectionnées sous forme de texte JSON';

  @override
  String get shareIcs => 'Partager en ICS';

  @override
  String get shareIcsDesc =>
      'Partager les calendriers sélectionnés au format .ics';

  @override
  String get saveIcs => 'Enregistrer en ICS';

  @override
  String get saveIcsDesc =>
      'Enregistrer les calendriers sélectionnés au format .ics';

  @override
  String get copyIcs => 'Copier le contenu ICS';

  @override
  String get copyIcsDesc =>
      'Copier les calendriers sélectionnés sous forme de texte ICS';

  @override
  String get importIcs => 'Importer du contenu ICS';

  @override
  String get icsContent => 'Contenu ICS';

  @override
  String get pasteIcsContentHint =>
      'Collez ici le contenu commençant par BEGIN:VCALENDAR';

  @override
  String importIcsPreviewPrompt(int count) {
    return '$count événements trouvés. Les ajouter comme nouvelle catégorie ou remplacer une catégorie existante ?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return '$count catégories importées avec $warningCount remarques';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Un événement sans heure de début a été ignoré.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Un événement dont l’heure de début n’est pas prise en charge a été ignoré.';

  @override
  String get importWarningAdjustedEnd =>
      'L’heure de fin d’un événement a été corrigée car elle ne suivait pas son heure de début.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Les champs ICS non pris en charge ont été ajoutés aux notes : $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Fréquence de répétition non prise en charge ignorée : $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Sélectionner les calendriers à copier au format ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Sélectionner les calendriers à exporter au format ICS';

  @override
  String get exportIcsText => 'Exporter le texte ICS';

  @override
  String get exportJsonText => 'Exporter le texte JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Les données de l’application ont été restaurées depuis la sauvegarde précédente, car le fichier principal n’a pas pu être chargé.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Le fichier de données principal et sa sauvegarde sont tous deux endommagés. L’application utilise maintenant des données vierges.';

  @override
  String get dataRecoveryCorruptTitle => 'Vos données doivent être restaurées';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked n’a pu lire ni le fichier de données principal ni sa sauvegarde. Des copies protégées ont été créées avant le blocage des écritures.';

  @override
  String get dataRecoveryIoFailureTitle => 'Le stockage est indisponible';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked ne peut pas accéder au stockage local pour le moment. Vérifiez l’accès au stockage et la disponibilité de l’appareil, puis réessayez. Les données existantes ne seront pas écrasées.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Mettez Sked à jour pour ouvrir ces données';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Ces données ont été créées par une version plus récente de Sked. Mettez l’application à jour avant de réessayer. Le redémarrage avec des données vierges est désactivé pour les protéger.';

  @override
  String get dataRecoveryRetryAction => 'Réessayer';

  @override
  String get dataRecoveryArtifactsHint =>
      'Les fichiers de récupération et les emplacements de stockage concernés figurent ci-dessous. Ne modifiez aucun fichier tant que vos données n’ont pas été restaurées.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Afficher les fichiers et emplacements de récupération';

  @override
  String get dataRecoveryStartFreshAction =>
      'Repartir avec de nouvelles données';

  @override
  String get dataRecoveryStartFreshConfirmTitle =>
      'Repartir avec de nouvelles données ?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Les copies protégées seront conservées, mais Sked créera un nouveau fichier de données local. Continuez uniquement si vous ne souhaitez pas d’abord réessayer la récupération.';

  @override
  String get previousMonth => 'Mois précédent';

  @override
  String get nextMonth => 'Mois suivant';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'En cours';

  @override
  String get deleteCourseTitle => 'Supprimer le cours';

  @override
  String get deleteCourseMessage => 'Supprimer ce cours ?';

  @override
  String get showLunarCalendar => 'Afficher le calendrier lunaire';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count événements';
  }

  @override
  String get defaultView => 'Vue par défaut';

  @override
  String get generalDefaultViewSection => 'Au démarrage';

  @override
  String get generalViewSwitchBehavior => 'Bouton de changement de vue';

  @override
  String get settingsWorkspaceMode => 'Espace de travail actif';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Masquer la navigation entre les espaces de travail';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Masquez la navigation des espaces de travail. Le menu de l’écran principal permet toujours de changer d’espace.';

  @override
  String get generalDateLabelFormat => 'Format d’affichage de la date';

  @override
  String get generalDateLabelFormatLocalized => 'Localisé (juil. 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Barres obliques (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Disposition de la barre d’outils';

  @override
  String get toolbarNavigationSection => 'Navigation dans la barre d’outils';

  @override
  String get toolbarNavigationHiddenBehavior => 'Éléments masqués';

  @override
  String get toolbarNavigationRemove => 'Masquer complètement';

  @override
  String get toolbarNavigationMore => 'Déplacer dans « Plus »';

  @override
  String get toolbarNavigationReorder =>
      'Réorganiser les éléments de la barre d’outils';

  @override
  String get toolbarNavigationVisibility =>
      'Afficher l’élément de la barre d’outils';

  @override
  String get toolbarNavigationTimetable => 'Sélecteur d’emploi du temps';

  @override
  String get toolbarNavigationWeek => 'Sélecteur de semaine';

  @override
  String get toolbarNavigationView => 'Changement de vue';

  @override
  String get toolbarNavigationCategory => 'Sélecteur de catégorie';

  @override
  String get toolbarNavigationDate => 'Sélecteur de date';

  @override
  String get generalToolbarWidthPolicy =>
      'Répartition de l’espace dans la barre d’outils';

  @override
  String get generalToolbarWidthContent => 'Répartition automatique';

  @override
  String get generalToolbarWidthBalanced => 'Équilibrée';

  @override
  String get generalToolbarWidthCalendarPriority => 'Priorité aux catégories';

  @override
  String get generalToolbarWidthDatePriority => 'Priorité à la date';

  @override
  String get generalViewSwitchCycle => 'Parcourir les vues successivement';

  @override
  String get generalViewSwitchMenu => 'Ouvrir le menu des vues';

  @override
  String get generalViewSwitchTooltip => 'Changer de vue';

  @override
  String get generalViewSwitchMenuTooltip => 'Choisir une vue';

  @override
  String get generalViewLongPressTodayHint =>
      'Appui long pour revenir à aujourd’hui';

  @override
  String get generalScheduleDisplaySection => 'Affichage de l’agenda';

  @override
  String get generalTimeGridSection => 'Grille horaire';

  @override
  String get generalPopupSection => 'Comportement des fenêtres contextuelles';

  @override
  String get quickActionsSection => 'Actions rapides';

  @override
  String get showAddCourseFab => 'Afficher le bouton flottant d’ajout de cours';

  @override
  String get showAddCourseFabHint =>
      'Affiche ou masque le bouton flottant d’ajout de cours en bas à droite de l’emploi du temps.';

  @override
  String get showAddEventFab =>
      'Afficher le bouton flottant d’ajout d’événement';

  @override
  String get showAddEventFabHint =>
      'Affiche ou masque le bouton flottant d’ajout d’événement en bas à droite de l’agenda.';

  @override
  String get enableLongPressAddCourse =>
      'Appui long sur une case vide pour ajouter un cours';

  @override
  String get enableLongPressAddCourseHint =>
      'Appuyez longuement sur une zone vide de la grille de l’emploi du temps pour ajouter un cours.';

  @override
  String get enableLongPressAddEvent =>
      'Appui long sur une case vide pour ajouter un événement';

  @override
  String get enableLongPressAddEventHint =>
      'Dans la vue Jour ou Semaine, appuyez longuement sur une zone vide de la grille horaire pour ajouter un événement.';

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
  String get developerNotificationDiagnostics => 'Diagnostic des notifications';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Vérifiez l’état de livraison sur Android, recréez le plan de rappels existant et envoyez des notifications de test sûres via le service habituel de notifications de Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Le diagnostic des notifications est disponible uniquement sur Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Le diagnostic des notifications sera disponible après le démarrage du coordinateur de l’agenda.';

  @override
  String get developerNotificationRefresh => 'Actualiser le diagnostic';

  @override
  String get developerNotificationSystemStatus =>
      'Autorisation des notifications système';

  @override
  String get developerNotificationPermissionAllowed => 'Autorisée';

  @override
  String get developerNotificationPermissionBlocked => 'Bloquée';

  @override
  String get developerNotificationExactAlarm => 'Alarmes exactes';

  @override
  String get developerNotificationExactAlarmAllowed => 'Autorisées';

  @override
  String get developerNotificationExactAlarmBlocked => 'Non autorisées';

  @override
  String get developerNotificationPlan => 'Plan de notifications de l’agenda';

  @override
  String get developerNotificationCoverage => 'Couverture des rappels';

  @override
  String get developerNotificationCoverageReady =>
      'Tous les rappels connus en nombre fini sont directement programmés';

  @override
  String get developerNotificationCoverageRenewable =>
      'Les rappels récurrents sont replanifiés au mieux sur le long terme';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'La capacité des alarmes directes est atteinte ; les rappels ultérieurs sont replanifiés au mieux';

  @override
  String get developerNotificationCoverageBlocked =>
      'Les conditions d’une livraison précise ne sont pas remplies';

  @override
  String get developerNotificationCoverageFailed =>
      'La dernière synchronisation des rappels a échoué';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled alarmes directes / capacité : $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled programmés, $planned prévus';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Dernière erreur : $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Recréer le plan de notifications';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Plan de notifications recréé.';

  @override
  String get developerNotificationTestChannel => 'Canal de test';

  @override
  String get developerNotificationTestCourse => 'Rappels de cours';

  @override
  String get developerNotificationTestSchedule => 'Rappels d’événements';

  @override
  String get developerNotificationImmediateTest => 'Envoyer un test immédiat';

  @override
  String get developerNotificationThirtySecondTest =>
      'Programmer un test en arrière-plan dans 30 secondes';

  @override
  String get developerNotificationImmediateQueued =>
      'Notification de test immédiat envoyée.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Test en arrière-plan programmé dans 30 secondes.';

  @override
  String get developerNotificationAppSwitch =>
      'Interrupteur des rappels de l’application';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Activé pour les rappels habituels';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Désactivé pour les rappels habituels ; les tests développeur restent disponibles';

  @override
  String get developerNotificationTimeZone => 'Fuseau horaire local';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Pas encore créé. Un test développeur le créera.';

  @override
  String get developerNotificationChannelEnabledState => 'Activé';

  @override
  String get developerNotificationChannelBlockedState => 'Bloqué';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Importance : $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Importance indisponible';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending en attente / $active actives';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Dernier affichage natif : $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Aucun rapprochement enregistré pour le moment.';

  @override
  String get developerNotificationNextReminder => 'Prochain rappel réel';

  @override
  String get developerNotificationNoPendingReminder =>
      'Aucun rappel futur dans le plan actuel';

  @override
  String get developerNotificationNextMaintenance => 'Prochaine maintenance';

  @override
  String get developerNotificationNextRenewal =>
      'Prochaine replanification au mieux';

  @override
  String get developerNotificationNoMaintenance => 'Non programmé';

  @override
  String get developerNotificationTruncation => 'Limitation du plan';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count omis en raison de la limite du plan';
  }

  @override
  String get developerNotificationLastReconciliation => 'Dernier rapprochement';

  @override
  String get developerNotificationLastSynchronization =>
      'Dernière synchronisation des rappels';

  @override
  String get developerNotificationLateRecovery =>
      'Rattrapage des rappels en retard';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count rappel(s) ont été rattrapés après l’heure initialement prévue';
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
  String get developerNotificationReconcileOriginForeground => 'Premier plan';

  @override
  String get developerNotificationReconcileOriginBackground => 'Arrière-plan';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Rapprochement de référence';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Maintenance';

  @override
  String get developerNotificationReconcileModeRecovery => 'Récupération';

  @override
  String get developerNotificationRunRecovery => 'Récupérer les rappels';

  @override
  String get developerNotificationRecoveryComplete =>
      'Récupération des rappels terminée';

  @override
  String get developerNotificationReconcileResultSuccess => 'Réussi';

  @override
  String get developerNotificationReconcileResultSkipped => 'Ignoré';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Bloqué tant que toutes les conditions de livraison précise ne sont pas remplies';

  @override
  String get developerNotificationReconcileResultFailed => 'Échec';

  @override
  String get developerNotificationBackgroundLimits =>
      'Restrictions du constructeur en arrière-plan';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Les restrictions du constructeur en arrière-plan peuvent affecter la livraison.';

  @override
  String get developerNotificationAutostart =>
      'Démarrage en arrière-plan du constructeur';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Constructeur : $vendor ; une entrée de ses réglages est disponible. Android ne permet pas de lire l’état de cette autorisation.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Constructeur : $vendor ; les informations de l’application seront ouvertes à la place. Android ne permet pas de lire l’état de cette autorisation.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Aucune entrée des réglages du constructeur pour l’arrière-plan n’est disponible.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Dernière destination ouverte : $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'réglages du constructeur';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'informations de l’application';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'aucune';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Limites de la récupération après redémarrage';

  @override
  String get developerNotificationRebootBoundary =>
      'La récupération commence après le premier déverrouillage ; une application arrêtée de force ne peut pas redémarrer seule.';

  @override
  String get developerNotificationTestChecking =>
      'Les tests sont indisponibles pendant la vérification de l’état des notifications.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Les tests sont indisponibles car les notifications système sont bloquées.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Les tests sont indisponibles car le canal de notification sélectionné est bloqué.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Gérée par les paramètres de notification de Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Sans objet sous Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Identité du package Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Identité MSIX disponible ; les notifications affichées peuvent être retirées';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Installez la version MSIX pour retirer de façon fiable les notifications affichées';

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
  String get notificationSettingsSection => 'Rappels et notifications';

  @override
  String get notificationCoverage => 'Couverture des rappels';

  @override
  String get notificationCoverageRenewable =>
      'Les événements récurrents sans date de fin sont replanifiés en arrière-plan pour maintenir la couverture à long terme.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android peut programmer directement jusqu’à $capacity rappels ; les suivants sont replanifiés à l’avance.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Activer les rappels et les notifications';

  @override
  String get notificationSettingsEnabledHint =>
      'Programme uniquement les éléments ayant un rappel. Définissez ci-dessous un rappel par défaut pour les cours qui en héritent.';

  @override
  String get notificationPrecisionLimitations =>
      'Les rappels dépendent des autorisations et de l’exécution en arrière-plan. Un arrêt, un changement d’heure ou des restrictions système peuvent les retarder.';

  @override
  String get notificationSettingsEnabledSummary => 'Activé';

  @override
  String get notificationSettingsDisabledSummary => 'Désactivé';

  @override
  String get notificationDefaultsSection => 'Rappels par défaut';

  @override
  String get notificationCourseDefaultReminder => 'Rappel par défaut des cours';

  @override
  String get notificationGeneralDefaultReminder =>
      'Rappel par défaut des événements';

  @override
  String get notificationReminderOff => 'Aucun rappel';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minutes avant';
  }

  @override
  String get notificationPermission => 'Autorisation de notification';

  @override
  String get notificationPermissionGranted => 'Autorisée par le système';

  @override
  String get notificationPermissionDenied => 'Bloquée par le système';

  @override
  String get notificationPermissionChecking =>
      'Vérification de l’autorisation…';

  @override
  String get notificationPermissionRequest => 'Demander l’autorisation';

  @override
  String get notificationPermissionOpenSettings =>
      'Ouvrir les paramètres système';

  @override
  String get notificationPermissionRequestFailed =>
      'Impossible de lire l’autorisation de notification. Réessayez.';

  @override
  String get notificationExactAlarm => 'Autorisation des alarmes exactes';

  @override
  String get notificationExactAlarmAllowed => 'Autorisée par le système';

  @override
  String get notificationExactAlarmRequired =>
      'Nécessaire pour des rappels à l’heure précise';

  @override
  String get notificationExactAlarmRequest => 'Autoriser les alarmes exactes';

  @override
  String get notificationBatteryOptimization => 'Optimisation de la batterie';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Exemption de l’optimisation de la batterie Android accordée';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Les rappels précis nécessitent une exemption de l’optimisation de la batterie Android';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Ouvrir les paramètres d’optimisation de la batterie';

  @override
  String get notificationAutostart =>
      'Démarrage en arrière-plan du constructeur';

  @override
  String get notificationAutostartVendorHint =>
      'Autorisez le démarrage automatique ou l’exécution en arrière-plan pour que les rappels puissent être restaurés après un redémarrage.';

  @override
  String get notificationAutostartFallbackHint =>
      'Ouvrez les informations de Sked et autorisez son exécution en arrière-plan. Android ne peut pas vérifier ce réglage du constructeur.';

  @override
  String get notificationAutostartUnavailable =>
      'Aucune page de réglages du constructeur n’a été trouvée. Vérifiez manuellement les informations de Sked.';

  @override
  String get notificationAutostartRequest =>
      'Ouvrir les réglages d’arrière-plan du constructeur';

  @override
  String get notificationAutostartOpenFailed =>
      'Impossible d’ouvrir les réglages d’arrière-plan du constructeur. Vérifiez manuellement les informations de Sked.';

  @override
  String get notificationLockScreenTitles =>
      'Afficher les titres sur l’écran verrouillé';

  @override
  String get notificationLockScreenTitlesHint =>
      'Lorsque cette option est désactivée, les détails des notifications restent privés sur l’écran verrouillé.';

  @override
  String get notificationWidgets => 'Widgets de l’écran d’accueil';

  @override
  String get notificationWidgetsDesc =>
      'Actualisez les widgets Sked et découvrez comment en ajouter un depuis le lanceur.';

  @override
  String get notificationWidgetsDialogTitle => 'Ajouter un widget Sked';

  @override
  String get notificationWidgetsDialogMessage =>
      'Sur l’écran d’accueil de votre appareil, appuyez longuement sur une zone vide, choisissez Widgets et ajoutez un widget Sked. Il affichera vos prochains cours ou événements.';

  @override
  String get notificationWidgetsRefresh => 'Actualiser les widgets';

  @override
  String get notificationWidgetsRefreshed => 'Widgets actualisés';

  @override
  String get notificationPlatformUnsupported =>
      'Cette plateforme ne propose pas de notifications natives.';

  @override
  String get workspaceFeatures => 'Gestion des fonctions';

  @override
  String get workspaceBoth => 'Emploi du temps et agenda';

  @override
  String get workspaceOnlyStudent => 'Emploi du temps uniquement';

  @override
  String get workspaceOnlyGeneral => 'Agenda uniquement';

  @override
  String get workspaceDisableTitle => 'Désactiver cet espace ?';

  @override
  String get workspaceDisableMessage =>
      'Les données et les préférences seront conservées. Ses fonctions et rappels seront suspendus jusqu’à sa réactivation ici.';

  @override
  String get workspaceEnableHint =>
      'Choisissez les fonctions à utiliser. Au moins une doit rester active.';

  @override
  String get workspaceLastRequired => 'Au moins un espace doit rester actif.';

  @override
  String get workspaceReminderCleanupFailed =>
      'L’espace est désactivé, mais les rappels n’ont pas pu être supprimés. Réessayez la récupération des notifications.';

  @override
  String get settingsSearch => 'Rechercher un réglage';

  @override
  String get settingsNoResults => 'Aucun réglage correspondant';

  @override
  String get settingsDataPrivacy => 'Données et confidentialité';

  @override
  String get workspacePreferences => 'Affichage et interactions';

  @override
  String get workspaceManage => 'Gérer';

  @override
  String get selectedDayAgenda => 'Jour sélectionné';

  @override
  String get notificationTroubleshooting => 'Autorisations et dépannage';

  @override
  String get settingsConnection => 'Connexion';

  @override
  String get settingsAdvanced => 'Avancé';

  @override
  String get unsavedChangesMessage =>
      'Des modifications ne sont pas enregistrées. Les abandonner et quitter ?';

  @override
  String get backupWorkspaceSelection =>
      'La sauvegarde complète inclut les données et le choix des espaces activés.';

  @override
  String get assistantLayoutPreview => 'IA · Aperçu de la disposition';

  @override
  String get assistantSelectionContext =>
      'Utilise la sélection actuelle comme contexte';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Brouillon du message';

  @override
  String get assistantPreviewNoSend =>
      'Aperçu de la disposition uniquement. Rien ne sera envoyé ni modifié.';

  @override
  String get resizePanel => 'Redimensionner le panneau';

  @override
  String get minimizeWindow => 'Réduire';

  @override
  String get maximizeWindow => 'Agrandir';

  @override
  String get restoreWindow => 'Restaurer la fenêtre';

  @override
  String get closeWindow => 'Fermer la fenêtre';

  @override
  String get courseSystemReminder => 'Rappel système';

  @override
  String courseReminderInherit(String reminder) {
    return 'Utiliser la valeur par défaut ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Les rappels système sont désactivés dans les réglages de notification. Cette préférence du cours peut tout de même être enregistrée.';

  @override
  String get courseReminderDefaultOff =>
      'Aucun rappel par défaut n’est défini pour les cours. Choisissez ici un rappel personnalisé ou définissez une valeur par défaut dans les réglages de notification.';

  @override
  String get courseReminderDeliveryHint =>
      'Cette préférence est enregistrée avec le cours. La livraison dépend des autorisations de notification du système et des restrictions d’arrière-plan.';

  @override
  String get courseReminderPermissionUnknown =>
      'L’état des notifications système n’a pas été vérifié. Consultez les réglages de notification avant de vous fier aux rappels.';

  @override
  String get courseReminderMinutesLabel => 'Minutes avant le cours';

  @override
  String get exportAction => 'Exporter';

  @override
  String get datePickerSelectWeek => 'Choisir une semaine';

  @override
  String get datePickerSelectMonth => 'Choisir un mois';

  @override
  String get generalDateLabelFormatDescription =>
      'S’applique à la navigation par date sur ordinateur et sur petit écran.';

  @override
  String get dateRangeTitle => 'Choisir une période';

  @override
  String get dateRangeCustom => 'Personnalisé';

  @override
  String get dateRangeChooseStart => 'Choisissez la date de début';

  @override
  String get dateRangeChooseEnd => 'Choisissez la date de fin';

  @override
  String get dateRangeLimit =>
      'Sélectionnez 1 à 14 jours, dates de début et de fin incluses.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'Personnalisé · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Choisir avec les roulettes';

  @override
  String get courseReminderUseDefault => 'Utiliser la valeur par défaut';

  @override
  String get courseReminderInvalidMinutes =>
      'Saisissez un nombre entier de minutes supérieur ou égal à zéro.';

  @override
  String get generalCustomColumnWidth =>
      'Largeur des colonnes de la vue personnalisée';

  @override
  String get generalCustomColumnWidthAuto => 'Automatique';

  @override
  String get generalCustomColumnWidthManual => 'Largeur minimale';

  @override
  String get generalCustomColumnWidthMinimum => 'Largeur minimale par jour';

  @override
  String get generalCustomColumnWidthHint =>
      'Toutes les dates partagent cette largeur minimale. Les colonnes occupent l’espace disponible ou défilent horizontalement. Concerne uniquement la vue personnalisée.';

  @override
  String get settingsAppearanceLanguage => 'Apparence et langue';

  @override
  String get settingsAppearanceDetails => 'Couleurs et contours';

  @override
  String get monthNoEvents => 'Aucun événement ce jour-là';

  @override
  String get settingsOverview => 'Vue d’ensemble';

  @override
  String get settingsThemeTarget => 'Thème pour';

  @override
  String get settingsColorMode => 'Mode de couleur';

  @override
  String get settingsNotificationPreferences => 'Préférences de rappel';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Rappels par défaut, autorisations et fiabilité';

  @override
  String get settingsFeaturesSummary => 'Espaces de travail et navigation';

  @override
  String get settingsPrivacySummary =>
      'Politique de confidentialité et suppression des données locales';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count périodes',
      one: '1 période',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Période';

  @override
  String get periodTimesDurationColumn => 'Durée';

  @override
  String get periodTimesGapColumn => 'Pause';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'En attente d’enregistrement…';

  @override
  String get periodTimesSaveFailed =>
      'Non enregistré · Échec de l’enregistrement';

  @override
  String get periodTimesInvalidStatus =>
      'Non enregistré · Corrigez les horaires signalés';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked ne peut pas confirmer si le dernier enregistrement a été annulé. Les écritures sont suspendues et les copies de récupération sont conservées. Vérifiez le stockage, puis réessayez le chargement.';

  @override
  String get settingsPanelDisplayMode => 'Affichage des panneaux';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Commun aux emplois du temps et aux agendas';

  @override
  String get settingsPanelDisplayOverlay => 'Superposition';

  @override
  String get settingsPanelDisplaySideBySide => 'Côte à côte';

  @override
  String get settingsPanelDisplayAutomatic => 'Automatique';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Se superpose à droite sans redimensionner le calendrier.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Privilégie côte à côte ; se superpose seulement si le calendrier devient trop étroit.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Affiche côte à côte si le calendrier reste lisible, sinon en superposition.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Désactiver Réglages ou Espace de travail dans la barre d’outils déplace cet élément dans Plus au lieu de le supprimer. Plus ne peut pas être masqué tant qu’il contient des actions essentielles. Le changement d’espace de travail apparaît uniquement lorsque la navigation inférieure est masquée et que plusieurs espaces de travail sont activés.';

  @override
  String get reminderEnded => 'Terminé';

  @override
  String get reminderAutoCloseHint =>
      'Fermeture après 10 secondes. Interagissez pour garder le panneau ouvert.';

  @override
  String get showReminderIndependently => 'Ouvrir séparément';

  @override
  String get categoryManagerTitle => 'Gérer les catégories';

  @override
  String get categoryHidden => 'Masquée';

  @override
  String get categoryShowOnCalendar => 'Afficher dans le calendrier';

  @override
  String get categoryHideOnCalendar => 'Masquer dans le calendrier';

  @override
  String get categoryEditColor => 'Modifier la couleur de la catégorie';

  @override
  String get categoryThemePalette => 'Palette du thème';

  @override
  String get categoryCustomColor => 'Personnalisée';

  @override
  String get colorHexInvalid =>
      'Saisissez une couleur hexadécimale à six caractères.';

  @override
  String categoryColorSlot(int number) {
    return 'Couleur du thème $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Les mises à jour du magasin peuvent arriver plus tard. Leur disponibilité est indiquée sur la page du magasin.';

  @override
  String get storePrereleaseNotice =>
      'Recevoir des avis de mises à jour en préversion ne vous inscrit pas à un programme de test du magasin.';

  @override
  String get updateFoundTitle => 'Nouvelle version disponible';

  @override
  String get updateNoNotes => 'Aucune note de version n’a été fournie.';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateRetry => 'Réessayer';

  @override
  String get updatePrerelease => 'Préversion';

  @override
  String get updateNetworkFailure =>
      'Impossible de rechercher les mises à jour. Vérifiez votre connexion et réessayez.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Aucune version plus récente trouvée (version actuelle : $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Restauration de la sauvegarde…';

  @override
  String get backupRestoreInProgressMessage =>
      'Les données et les paramètres pourront être modifiés une fois la restauration terminée. Vous pouvez toujours les consulter.';
}
