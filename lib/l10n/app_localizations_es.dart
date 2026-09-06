// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Semana $week';
  }

  @override
  String get addCourse => 'Añadir curso';

  @override
  String get settings => 'Ajustes';

  @override
  String get multiTimetableSwitch => 'Cambiar horario';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Horario actual · $weeks semanas';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Toca para cambiar · $weeks semanas';
  }

  @override
  String get editTimetable => 'Editar horario';

  @override
  String get schoolImportResultEditorTitle => 'Editar resultado analizado';

  @override
  String get schoolImportParsePageTitle => 'Analizar horario';

  @override
  String get schoolImportParsePageParsing => 'Analizando…';

  @override
  String get schoolImportParsePageFailed => 'Error al analizar';

  @override
  String get schoolImportParsePageComplete => 'Análisis completado';

  @override
  String get schoolImportParsePageContinue => 'Continuar';

  @override
  String get schoolImportParsePageRawContent => 'Respuesta sin procesar';

  @override
  String get schoolImportParsePageExpandRaw =>
      'Expandir respuesta sin procesar';

  @override
  String get schoolImportParsePageCollapseRaw =>
      'Contraer respuesta sin procesar';

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
  String get createTimetable => 'Nuevo horario';

  @override
  String get jumpToWeek => 'Ir a la semana';

  @override
  String get timetable => 'Horario';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Nombre del horario';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Semanas totales';

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get deleteTimetableTitle => 'Eliminar horario';

  @override
  String deleteTimetableMessage(Object name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Aún no hay horario';

  @override
  String get noTimetableMessage =>
      'Crea un horario o importa uno desde un archivo JSON.';

  @override
  String get importTimetable => 'Importar horario';

  @override
  String get courseName => 'Nombre del curso';

  @override
  String get location => 'Ubicación';

  @override
  String get dayOfWeek => 'Día';

  @override
  String get semesterWeeks => 'Semanas';

  @override
  String get startTime => 'Hora de inicio';

  @override
  String get endTime => 'Hora de fin';

  @override
  String get linkedPeriods => 'Periodos vinculados';

  @override
  String get linkedPeriodsUnmatched =>
      'Ningún periodo coincide con la hora actual. Toca para elegir manualmente.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Periodo $start-$end';
  }

  @override
  String get teacherName => 'Profesor';

  @override
  String get credits => 'Créditos';

  @override
  String get remarks => 'Observaciones';

  @override
  String get customFields => 'Campos personalizados';

  @override
  String get customFieldsHint => 'Uno por línea, formato: clave:valor';

  @override
  String get more => 'Más';

  @override
  String get selectDayOfWeek => 'Elegir día';

  @override
  String get selectSemesterWeeks => 'Elegir semanas';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get clear => 'Borrar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get selectLinkedPeriods => 'Elegir periodos vinculados';

  @override
  String get addCourseTitle => 'Añadir curso';

  @override
  String get editCourseTitle => 'Editar curso';

  @override
  String get editCourseTooltip => 'Editar curso';

  @override
  String get place => 'Ubicación';

  @override
  String get time => 'Hora';

  @override
  String get notFilled => 'Sin completar';

  @override
  String get none => 'Ninguno';

  @override
  String get conflictCourses => 'Cursos en conflicto';

  @override
  String get locationNotFilled => 'Ubicación sin completar';

  @override
  String get setAsDisplayed => 'Establecer como mostrado';

  @override
  String get editThisCourse => 'Editar este curso';

  @override
  String get settingsTitle => 'Ajustes';

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
      'No hay un horario disponible actualmente para los ajustes.';

  @override
  String get semesterStartDate => 'Fecha de inicio del semestre';

  @override
  String get periodTimeSets => 'Conjunto de horarios de periodos';

  @override
  String get noPeriodTimeAvailable =>
      'No hay conjuntos de horarios de periodos disponibles';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count periodos';
  }

  @override
  String get coursePopupDismissSetting =>
      'Permitir tocar fuera para cerrar el popup del curso';

  @override
  String get coursePopupDismissSettingHint =>
      'Desactivar esto también desactiva el cierre deslizando hacia abajo.';

  @override
  String get preserveTimetableGaps => 'Mantener huecos del horario';

  @override
  String get preserveTimetableGapsHint =>
      'Si está desactivado, los huecos de almuerzo y descansos se colapsan para que las clases posteriores suban.';

  @override
  String get showPastEndedCourses => 'Mostrar cursos ya finalizados';

  @override
  String get showPastEndedCoursesHint =>
      'Muestra los cursos que ya terminaron según la semana real actual con un estilo gris más claro.';

  @override
  String get showFutureCourses => 'Mostrar cursos futuros';

  @override
  String get showFutureCoursesHint =>
      'Muestra los cursos que no están activos esta semana pero aparecerán en semanas posteriores con un estilo gris.';

  @override
  String get timetableDisplaySettings =>
      'Visualización e interacción del horario';

  @override
  String get timetableDisplaySettingsDesc =>
      'Vista de clases, diseño, gestos semanales y adición rápida';

  @override
  String get showTimetableGridLines =>
      'Mostrar líneas de cuadrícula del horario';

  @override
  String get showTimetableGridLinesHint =>
      'Controla si las líneas de cuadrícula horizontales y verticales son visibles en el horario.';

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
  String get liveCourseOutlineColor => 'Color del contorno del curso';

  @override
  String get liveCourseOutlineColorHint =>
      'Elige si los contornos apuntan al curso actual/siguiente o a todos los cursos mostrados en la página actual.';

  @override
  String get liveCourseOutlineSettings => 'Contorno del curso';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Configura si el contorno está habilitado, a qué apunta, si sigue el color del tema y el color efectivo del contorno.';

  @override
  String get liveCourseOutlineEnabled => 'Activar contorno';

  @override
  String get liveCourseOutlineFollowTheme => 'Seguir color del tema';

  @override
  String get liveCourseOutlineTarget => 'Destino del contorno';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Curso actual/siguiente';

  @override
  String get liveCourseOutlineTargetAllDisplayed =>
      'Todos los cursos mostrados';

  @override
  String get liveCourseOutlineEffectiveColor => 'Color efectivo';

  @override
  String get liveCourseOutlineCustomColor => 'Color de contorno personalizado';

  @override
  String get liveCourseOutlineWidth => 'Ancho del contorno';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Idioma';

  @override
  String get languagePageDescription =>
      'Elige uno de los idiomas que realmente están disponibles en la app.';

  @override
  String get languageChinese => 'Chino';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Respuesta de la API';

  @override
  String get theme => 'Tema';

  @override
  String get themeFollowSystem => 'Seguir el sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeColor => 'Color del tema';

  @override
  String get themeColorModeSingle => 'Un solo color de tema';

  @override
  String get themeColorModeColorful => 'Colorido';

  @override
  String get themeColorUiColors => 'Colores de la interfaz';

  @override
  String get themeColorCourseColors => 'Colores de los cursos';

  @override
  String get themeColorPrimary => 'Primario';

  @override
  String get themeColorSecondary => 'Secundario';

  @override
  String get themeColorTertiary => 'Terciario';

  @override
  String get themeColorCourseText => 'Texto del curso';

  @override
  String get themeColorCourseTextAuto => 'Automático';

  @override
  String get themeColorCourseTextCustom => 'Color personalizado';

  @override
  String get themeColorCourseColorsEmpty =>
      'Los colores de los cursos se generarán después de importar un horario.';

  @override
  String get themeCustomColor => 'Color personalizado';

  @override
  String get themeApplyCustomColor => 'Aplicar color';

  @override
  String get themeApplySettings => 'Aplicar ajustes';

  @override
  String get dataImportExport => 'Importar y exportar datos';

  @override
  String get dataImportExportDesc =>
      'Importa todos los datos o un solo horario, o exporta el horario actual/todos.';

  @override
  String get appBackupTitle => 'Copia de seguridad y restauración de la app';

  @override
  String get appBackupSubtitle =>
      'Haz copias de seguridad o restaura horarios, agendas, ajustes y sitios escolares. Las claves de API no se incluyen.';

  @override
  String get appBackupSheetSubtitle =>
      'Una restauración completa reemplaza los datos actuales de la app. Las claves de la API de IA viven en el almacenamiento seguro y no se escriben en los archivos de copia.';

  @override
  String get restoreBackupFileTitle => 'Restaurar desde archivo JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Elige un archivo de copia completa de Sked. Confirmarás antes de restaurar.';

  @override
  String get restoreBackupTextTitle => 'Pegar JSON de copia';

  @override
  String get restoreBackupTextSubtitle =>
      'Pega una copia completa y restaura los datos actuales de la app.';

  @override
  String get shareBackupTitle => 'Compartir archivo de copia';

  @override
  String get shareBackupSubtitle =>
      'Exporta todos los datos de la app como JSON. Se excluyen las claves de API.';

  @override
  String get saveBackupTitle => 'Guardar archivo de copia';

  @override
  String get saveBackupSubtitle =>
      'Guarda una copia completa de la app en un archivo local.';

  @override
  String get copyBackupTitle => 'Copiar texto de copia';

  @override
  String get copyBackupSubtitle =>
      'Muestra el JSON completo de la copia para que puedas copiarlo o guardarlo temporalmente.';

  @override
  String get restoreBackupConfirmTitle => '¿Restaurar copia completa?';

  @override
  String get restoreBackupConfirmMessage =>
      'Esto reemplaza todos los horarios, agendas generales, ajustes y sitios escolares actuales. Las claves de API no se importan desde las copias; vuelve a introducir la clave antes de analizar horarios de nuevo.';

  @override
  String get restoreBackupConfirmAction => 'Restaurar copia';

  @override
  String get restoreBackupSuccessMessage =>
      'Copia completa de la app restaurada. Debes volver a introducir las claves de la API de IA.';

  @override
  String get restoreBackupFailureMessage =>
      'No se pudo restaurar. Revisa el contenido de la copia e inténtalo de nuevo.';

  @override
  String get openSourceLicenses => 'Licencias de código abierto';

  @override
  String get openSourceLicensesDesc =>
      'Ver licencias de las dependencias de Flutter y de los recursos del icono de la app incluidos.';

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Ya tienes la versión más reciente ($version)';
  }

  @override
  String get currentVersionLabel => 'Versión actual';

  @override
  String get newVersionAvailable => 'Actualización disponible';

  @override
  String get latestVersionLabel => 'Última versión';

  @override
  String get updateContentLabel => 'Detalles de la actualización';

  @override
  String get officialWebsite => 'Sitio web oficial';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Unidad en la nube';

  @override
  String get ignoreThisVersion => 'Ignorar esta versión';

  @override
  String get openUpdatesFailed => 'No se pudo abrir el enlace de actualización';

  @override
  String get updateCheckFailedTitle =>
      'Falló la comprobación de actualizaciones';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Repositorio de GitHub';

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
      'No se pudo abrir el enlace del repositorio de GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'No se pudo abrir el enlace de la política de privacidad';

  @override
  String get selectPeriodTimeSet => 'Elegir conjunto de horarios de periodos';

  @override
  String get newItem => 'Nuevo';

  @override
  String get editPeriodTimeSet => 'Editar conjunto de horarios de periodos';

  @override
  String get importTimetableFiles => 'Importar horario';

  @override
  String get importTimetableFilesDesc =>
      'Admite uno o varios archivos de horario.';

  @override
  String get importTimetableText => 'Importar horario desde texto';

  @override
  String get importTimetableTextDesc =>
      'Pega el contenido JSON del horario e impórtalo.';

  @override
  String get shareTimetableFiles => 'Compartir archivos de horario';

  @override
  String get shareTimetableFilesDesc => 'Elige primero uno o varios horarios.';

  @override
  String get saveTimetableFiles => 'Guardar archivos de horario';

  @override
  String get saveTimetableFilesDesc => 'Elige primero uno o varios horarios.';

  @override
  String get exportTimetableText => 'Exportar horario como texto';

  @override
  String get exportTimetableTextDesc =>
      'Elige uno o varios horarios y luego copia el contenido JSON.';

  @override
  String get jsonContent => 'Contenido JSON';

  @override
  String get pasteJsonContentHint => 'Pega el contenido JSON para importar.';

  @override
  String get jsonContentEmpty => 'Primero pega el contenido JSON.';

  @override
  String get copyText => 'Copiar';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get share => 'Compartir';

  @override
  String get selectTimetablesToExport => 'Elegir horarios para exportar';

  @override
  String get selectTimetablesToImport => 'Elegir horarios para importar';

  @override
  String timetableCourseCount(int count) {
    return '$count cursos';
  }

  @override
  String get importAction => 'Importar';

  @override
  String get importTimetableDialogTitle => 'Importar horario';

  @override
  String get chooseImportMethod => 'Elige cómo importar.';

  @override
  String get importAsNewTimetable => 'Importar como nuevo horario';

  @override
  String get replaceCurrentTimetable => 'Reemplazar el horario actual';

  @override
  String get importPeriodTimeSetDialogTitle =>
      'Importar conjuntos de horarios de periodos';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Este archivo contiene conjuntos de horarios de periodos incluidos. ¿Quieres importarlos y asociarlos?';

  @override
  String get importBundledPeriodTimeSets => 'Importar y asociar';

  @override
  String get discardBundledPeriodTimeSets => 'Descartar conjuntos incluidos';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'No hay ningún conjunto de horarios de periodos existente disponible, por lo que no se pueden descartar los conjuntos incluidos.';

  @override
  String savedToPath(Object path) {
    return 'Guardado en $path';
  }

  @override
  String get saveCancelled => 'Guardado cancelado';

  @override
  String get fileSaveRestrictedTitle => 'Guardado de archivos restringido';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'El sistema no pudo guardar el archivo. Puedes intentarlo de nuevo o usar compartir en su lugar.';

  @override
  String get retrySave => 'Intentar guardar de nuevo';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Activa el acceso a archivos en los ajustes del sistema y luego vuelve e intenta exportar otra vez.';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get browserDownloadRestrictedTitle =>
      'Descarga del navegador restringida';

  @override
  String get browserDownloadRestrictedMessage =>
      'Este navegador no admite guardar directamente en un archivo local. Comprueba los permisos de descarga del navegador o usa el uso compartido de archivos en su lugar.';

  @override
  String get switchToShare => 'Usar compartir en su lugar';

  @override
  String get fileSaveFailedTitle => 'Falló el guardado del archivo';

  @override
  String get fileSaveFailedWindowsMessage =>
      'No se puede escribir en la ruta actual. La carpeta de destino puede estar protegida, el archivo puede estar en uso o la ruta puede no ser escribible.';

  @override
  String get fileSaveFailedGenericMessage =>
      'El sistema no pudo guardar el archivo. Puedes intentarlo de nuevo, revisar los ajustes del sistema o usar el uso compartido de archivos en su lugar.';

  @override
  String get retryLater => 'Intentarlo de nuevo más tarde';

  @override
  String get exportSwitchedToShare =>
      'Se cambió a compartir archivos para la exportación';

  @override
  String get saveFailedRetry =>
      'No se pudo guardar. Inténtalo de nuevo más tarde.';

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
  String get appInstanceBlockedTitle => 'Sked ya está abierto';

  @override
  String get appInstanceBlockedMessage =>
      'Otra ventana de Sked o pestaña del navegador está usando tus datos locales. Ciérrala y vuelve a intentarlo.';

  @override
  String get appInstanceLeaseFailedTitle =>
      'Los datos locales no están disponibles';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked no pudo verificar el acceso exclusivo a los datos locales. Tus datos no se abrieron ni se modificaron. Comprueba el acceso al almacenamiento y vuelve a intentarlo.';

  @override
  String get savingChanges => 'Guardando cambios...';

  @override
  String get showApiKey => 'Mostrar clave de API';

  @override
  String get hideApiKey => 'Ocultar clave de API';

  @override
  String get importFailedCheckContent =>
      'La importación falló. Revisa el contenido del archivo.';

  @override
  String get noImportableTimetables =>
      'No se encontraron horarios utilizables en el archivo importado.';

  @override
  String importedTimetablesCount(int count) {
    return 'Se importaron $count horarios';
  }

  @override
  String get periodTimesTitle => 'Horarios de periodos';

  @override
  String get importExport => 'Importar y exportar';

  @override
  String get importPeriodTemplate => 'Importar plantilla de periodos';

  @override
  String get importPeriodTemplateText =>
      'Importar plantilla de periodos desde texto';

  @override
  String get sharePeriodTemplate => 'Compartir plantilla de periodos';

  @override
  String get saveTemplateToFile => 'Guardar plantilla en archivo';

  @override
  String get exportPeriodTemplateText =>
      'Exportar plantilla de periodos como texto';

  @override
  String get deletePeriodTimeSet => 'Eliminar conjunto de horarios de periodos';

  @override
  String get periodTimeSetName => 'Nombre del conjunto de horarios de periodos';

  @override
  String get addOnePeriod => 'Añadir periodo';

  @override
  String periodNumberLabel(int index) {
    return 'Periodo $index';
  }

  @override
  String get deleteThisPeriod => 'Eliminar este periodo';

  @override
  String durationMinutes(int minutes) {
    return 'Duración $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Intervalo desde el anterior $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'La hora de fin debe ser posterior a la de inicio';

  @override
  String get periodOverlapPrevious =>
      'Este periodo se superpone con el anterior';

  @override
  String get periodTimesSaved => 'Horarios de periodos guardados';

  @override
  String get deletePeriodTimeSetTitle =>
      'Eliminar conjunto de horarios de periodos';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'conjunto actual de horarios de periodos';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Se importaron $count horarios de periodos';
  }

  @override
  String get periodFilePermissionTitle => 'Se necesita permiso de archivos';

  @override
  String get androidFilePermissionMessage =>
      'La exportación en Android requiere permiso de acceso a archivos. Concede el permiso para continuar guardando.';

  @override
  String get reauthorize => 'Autorizar de nuevo';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Permiso denegado permanentemente';

  @override
  String get permissionSettingsExportMessage =>
      'Activa el acceso a archivos en los ajustes del sistema y luego vuelve e intenta exportar otra vez.';

  @override
  String get privacyPolicyTitle => 'Política de privacidad';

  @override
  String get privacyPolicyEntryDesc =>
      'Descubre cómo la app gestiona el almacenamiento local, la configuración de sitios escolares, la importación/exportación de archivos, el análisis de páginas web y los enlaces externos.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Versión aceptada: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked es una herramienta de horarios que prioriza el almacenamiento local. Los horarios, conjuntos de periodos y configuración de sitios escolares se almacenan solo en tu dispositivo o navegador y nunca se suben automáticamente. La app solo procesa datos cuando activas explícitamente acciones como importar, analizar páginas web, compartir o abrir enlaces externos. La política de privacidad completa está disponible en línea.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Almacenamiento local';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Importación y exportación';

  @override
  String get privacyPolicyImportExportBody =>
      'La app lee o escribe archivos JSON de horarios, archivos JSON de sitios escolares y archivos de plantillas de periodos solo cuando eliges explícitamente un archivo o inicias una acción de exportación. Importar estos archivos es una operación local a menos que también elijas el análisis de páginas web. Obtener una lista de modelos personalizados también es una acción de red explícita y solo contacta el endpoint personalizado que configuraste.';

  @override
  String get privacyPolicySharingTitle => 'Compartir';

  @override
  String get privacyPolicySharingBody =>
      'Cuando usas explícitamente compartir, la app pasa el archivo exportado a la hoja de compartir del sistema o a la app de destino que elijas. Cómo se maneja ese archivo después depende de la app o del servicio de destino que hayas seleccionado.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Enlaces externos';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Cuando abres enlaces externos como el repositorio de GitHub, la app entrega la acción a tu navegador u otra aplicación externa. El tratamiento de los datos a partir de ese momento se rige por el tercero que abras.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Qué no recopila la app';

  @override
  String get privacyPolicyNoCollectionBody =>
      'La app no requiere una cuenta de Sked y no habilita análisis, identificadores publicitarios ni copia de seguridad en la nube. Tampoco ofrece un campo dedicado para recopilar contraseñas de cuentas escolares. Si inicias sesión en un sitio web escolar dentro de la app, esa interacción ocurre en la página escolar que abriste.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Análisis de páginas web';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Cuando usas la importación de una página web escolar o analizas texto de horario / HTML pegado, la app primero prepara y limpia el contenido localmente y luego envía el texto de horario, texto de página o contenido HTML enviado, el título y la URL opcionales de la página, el idioma actual de la app y el contenido del prompt del analizador al endpoint compatible con OpenAI que configuraste. La obtención de la lista de modelos también solicita ese mismo endpoint. Sked no proporciona un endpoint de análisis integrado ni envía solicitudes de análisis a un backend de análisis de horarios controlado por el desarrollador. El endpoint personalizado y cualquier servicio ascendente pueden almacenar, reenviar, limitar, eliminar o procesar los datos de otro modo según las reglas del proveedor de servicios que elijas. Si usas una Base URL http://, úsala solo en dispositivos, redes y servicios de endpoint de confianza, porque el contenido y las claves API podrían no estar protegidos por cifrado de transporte.';

  @override
  String get privacyPolicyUpdatesTitle => 'Actualizaciones de la política';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'La versión actual de la política de privacidad es $version. Si una versión posterior cambia la forma en que se manejan los datos, la app puede pedirte que leas y aceptes la política actualizada de nuevo.';
  }

  @override
  String get privacyGateTitle =>
      'Acepta la política de privacidad antes de usar la app';

  @override
  String get privacyGateSummaryStorage =>
      'Los horarios, los conjuntos de horarios de periodos y la configuración de sitios escolares solo se almacenan localmente y no se suben automáticamente a un servidor del desarrollador.';

  @override
  String get privacyGateSummaryImportExport =>
      'La importación, exportación y el uso compartido solo ocurren cuando los inicias explícitamente; el análisis de páginas web envía solo el contenido comprimido que envías al endpoint de análisis configurado, y puedes revisar el horario analizado antes de guardarlo.';

  @override
  String get privacyGateSummaryUpdates =>
      'Si una versión posterior cambia la forma en que se manejan los datos, la app puede pedirte que revises la política de privacidad actualizada de nuevo.';

  @override
  String get schoolWebImportEntry => 'Importar desde página web escolar';

  @override
  String get schoolWebImportEntryDesc =>
      'Importa la página actual del horario desde el sitio escolar.';

  @override
  String get schoolSitesManageEntry => 'Gestionar sitios escolares';

  @override
  String get schoolSitesManageEntryDesc =>
      'Añade, edita y elimina URLs de inicio de sesión escolar, con importación y exportación JSON.';

  @override
  String get schoolSitesPageTitle => 'Gestión de sitios escolares';

  @override
  String get schoolSitesImportJson => 'Importar JSON de escuelas';

  @override
  String get schoolSitesShareJson => 'Compartir JSON de escuelas';

  @override
  String get schoolSitesSaveJson => 'Guardar JSON de escuelas';

  @override
  String get schoolSitesSaved => 'Sitios escolares guardados';

  @override
  String get schoolSitesImported => 'Sitios escolares importados';

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
      'Aún no hay configuración de sitios escolares.';

  @override
  String get schoolSitesNameLabel => 'Nombre de la escuela';

  @override
  String get schoolSitesLoginUrlLabel => 'URL de inicio de sesión';

  @override
  String get schoolSitesAdd => 'Añadir escuela';

  @override
  String get schoolSitesEdit => 'Editar escuela';

  @override
  String get schoolSitesDeleteTitle => 'Eliminar escuela';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Primero completa el nombre de la escuela y la URL de inicio de sesión.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Importar pegando el contenido de la página del horario';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Pega manualmente el código fuente o el contenido sin procesar de la página que contiene información del horario.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Analizar horario desde el contenido de la página';

  @override
  String get schoolHtmlImportUrlLabel => 'URL de origen (opcional)';

  @override
  String get schoolHtmlImportTitleLabel => 'Título de la página (opcional)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Contenido de la página';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Pega aquí el código fuente o el contenido sin procesar de la página que contiene información del horario.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Se puede analizar e importar cualquier contenido que contenga información del horario, no solo HTML.';

  @override
  String get schoolHtmlImportCompress => 'Preparar contenido';

  @override
  String get schoolHtmlImportCompressed => 'Contenido preparado';

  @override
  String get schoolHtmlImportCompressFirst => 'Prepara primero el contenido.';

  @override
  String get schoolHtmlImportSubmit => 'Analizar e importar';

  @override
  String get schoolImportContentTruncated =>
      'Esta página alcanzó el límite seguro de importación. Solo se enviará para su análisis la parte capturada.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'El análisis puede tardar un poco. Espera, por favor.';

  @override
  String get schoolHtmlImportEmpty => 'Primero pega el HTML de la página.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Volver a la página web';

  @override
  String get schoolWebImportPageTitle => 'Importación desde página web escolar';

  @override
  String get schoolWebImportPreview => 'Vista previa de importación';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count cursos';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count periodos';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Título de la página';

  @override
  String get schoolWebImportParserUsed => 'Analizador';

  @override
  String get schoolWebImportWarnings => 'Notas de importación';

  @override
  String get schoolWebImportParserDetails => 'Detalles del análisis';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Expandir los detalles del análisis';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Contraer los detalles del análisis';

  @override
  String get schoolWebImportOpenPageHint =>
      'Inicia sesión en el sitio escolar dentro de la app y luego navega manualmente a la página del horario.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Esta plataforma aún no admite el inicio de sesión web incrustado. Usa una plataforma con compatibilidad con WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Elegir escuela';

  @override
  String get schoolWebImportNoSchools =>
      'No hay ninguna configuración de escuela disponible. Revisa primero school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'No se pudo cargar la configuración de la escuela. Revisa el formato del archivo JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importar la página actual';

  @override
  String get schoolWebImportLoadingPage => 'Cargando página…';

  @override
  String get schoolWebImportParsing => 'Analizando la página actual…';

  @override
  String get schoolWebImportLoadFailed =>
      'No se pudo cargar la página. Actualiza o inténtalo de nuevo más tarde.';

  @override
  String get schoolWebImportUnknownOrigin => 'Sitio desconocido';

  @override
  String get schoolWebImportExitTitle => '¿Salir del navegador?';

  @override
  String get schoolWebImportExitMessage =>
      'La página se cerrará. Se perderá todo lo que aún no hayas importado.';

  @override
  String get schoolWebImportExitConfirm => 'Salir';

  @override
  String get schoolWebImportEmptyPage =>
      'El contenido actual de la página está vacío y aún no se puede importar.';

  @override
  String get schoolWebImportSuccess => 'Horario web importado';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Fuente del analizador';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Compatible con OpenAI personalizado';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Analizador personalizado compatible con OpenAI';

  @override
  String get schoolImportParserCustomPromptTitle => 'Prompt personalizado';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Edita aquí el prompt integrado del analizador. Los cambios solo afectan al analizador personalizado compatible con OpenAI.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'El prompt integrado se carga aquí por defecto. Bórralo para volver a la versión integrada.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Restablecer prompt predeterminado';

  @override
  String get schoolImportParserBaseUrl => 'Base URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'La Base URL debe ser una URL HTTP o HTTPS con host.';

  @override
  String get schoolImportParserApiKey => 'API key';

  @override
  String get schoolImportParserModel => 'Modelo';

  @override
  String get schoolImportParserFetchModels => 'Obtener lista de modelos';

  @override
  String get schoolImportParserFetchingModels => 'Obteniendo modelos...';

  @override
  String get schoolImportParserNoModelsFound =>
      'El endpoint no devolvió ningún modelo.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'No se pudieron obtener los modelos. Comprueba el punto de conexión e inténtalo de nuevo.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Se obtuvieron $count modelos';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      '¿Usar un endpoint HTTP sin cifrar?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'La clave de API y el contenido del horario pueden leerse o modificarse durante el tránsito. Continúa solo si confías en este dispositivo, la red y el endpoint. Esta aprobación dura hasta que cierres Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'La configuración del analizador personalizado está incompleta. Primero completa Base URL, API key y modelo.';

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
    return 'Analizador: Personalizado ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Ver la política de privacidad completa';

  @override
  String get privacyAgreeAndContinue => 'Aceptar y continuar';

  @override
  String get privacyDecline => 'Rechazar';

  @override
  String get privacyDeclineWebHint =>
      'Este entorno del navegador no permite que la app cierre la página por ti. Si no aceptas, cierra esta pestaña o ventana manualmente.';

  @override
  String get defaultPeriodTimeSetName => 'Periodos predeterminados';

  @override
  String get periodTimeSetFallbackName => 'Horarios de periodos';

  @override
  String get untitledTimetableName => 'Horario sin título';

  @override
  String get newTimetableName => 'Nuevo horario';

  @override
  String get newPeriodTimeSetName => 'Nuevo conjunto de horarios de periodos';

  @override
  String get emptyTimetableName => 'Horario vacío';

  @override
  String importedPeriodTimeSetName(Object name) {
    return 'Periodos de $name';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'El tipo de archivo importado no coincide.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Esta versión del archivo importado aún no es compatible.';

  @override
  String get noPeriodTimesInImportMessage =>
      'No se encontraron horarios de periodos en el archivo importado.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Selecciona al menos un horario.';

  @override
  String get noExportableTimetableMessage =>
      'No hay ningún horario disponible para exportar.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Reemplazar el horario actual solo permite seleccionar un horario.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'No hay un horario actual para reemplazar.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Este conjunto de horarios de periodos todavía está siendo usado por $count horario(s). Reasígnalos antes de eliminarlo.';
  }

  @override
  String get weekdayMonday => 'Lunes';

  @override
  String get weekdayTuesday => 'Martes';

  @override
  String get weekdayWednesday => 'Miércoles';

  @override
  String get weekdayThursday => 'Jueves';

  @override
  String get weekdayFriday => 'Viernes';

  @override
  String get weekdaySaturday => 'Sábado';

  @override
  String get weekdaySunday => 'Domingo';

  @override
  String get weekdayShortMonday => 'Lun';

  @override
  String get weekdayShortTuesday => 'Mar';

  @override
  String get weekdayShortWednesday => 'Mié';

  @override
  String get weekdayShortThursday => 'Jue';

  @override
  String get weekdayShortFriday => 'Vie';

  @override
  String get weekdayShortSaturday => 'Sáb';

  @override
  String get weekdayShortSunday => 'Dom';

  @override
  String get monthJanuary => 'Ene';

  @override
  String get monthFebruary => 'Feb';

  @override
  String get monthMarch => 'Mar';

  @override
  String get monthApril => 'Abr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'Jun';

  @override
  String get monthJuly => 'Jul';

  @override
  String get monthAugust => 'Ago';

  @override
  String get monthSeptember => 'Sep';

  @override
  String get monthOctober => 'Oct';

  @override
  String get monthNovember => 'Nov';

  @override
  String get monthDecember => 'Dic';

  @override
  String get semesterWeeksWholeTerm => 'Todo el semestre';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Semanas $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Semanas $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Elige el modo inicial';

  @override
  String get firstLaunchSubtitle =>
      'Elige el espacio de trabajo que más uses. Puedes cambiar de modo más tarde.';

  @override
  String get firstLaunchStudentDesc =>
      'Gestiona horarios, cursos, semanas, horas de clase e importaciones.';

  @override
  String get firstLaunchGeneralDesc =>
      'Gestiona categorías, eventos, recordatorios y datos JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Empezar con horario';

  @override
  String get firstLaunchStartGeneral => 'Empezar con agenda';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Al elegir un espacio de trabajo inicial, confirmas que has leído y aceptas la ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Política de privacidad';

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
  String get today => 'Hoy';

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
      'Vistas, barra de herramientas, formato de fecha y adición rápida';

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
  String get viewWeek => 'Semana';

  @override
  String get viewDay => 'Día';

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
  String get developerModeTitle => 'Modo de desarrollador';

  @override
  String get developerModeDescription =>
      'Herramientas para añadir datos de ejemplo completos y comprobar la interfaz y la interacción.';

  @override
  String get developerSampleLanguage => 'Idioma de los datos de ejemplo';

  @override
  String get developerSampleChinese => 'Chino';

  @override
  String get developerSampleEnglish => 'Inglés';

  @override
  String get developerSampleDataDescription =>
      'Añade un horario y un conjunto de categorías y eventos sin reemplazar los datos existentes.';

  @override
  String get developerAddSampleData => 'Añadir datos de ejemplo';

  @override
  String get developerSampleDataAdded =>
      'Se añadieron el horario y los eventos de ejemplo.';

  @override
  String get developerModeLongPressHint =>
      'Mantén pulsado durante 3 segundos para abrir el modo de desarrollador';

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
      'Contraer navegación del espacio de trabajo';

  @override
  String get expandWorkspaceNavigation =>
      'Expandir navegación del espacio de trabajo';

  @override
  String get schoolWebImportExitBrowser => 'Salir del navegador integrado';

  @override
  String get schoolWebImportEditAddress => 'Editar dirección';

  @override
  String get schoolWebImportAddressLabel => 'Dirección web';

  @override
  String get schoolWebImportOpenAddress => 'Abrir';

  @override
  String get schoolWebImportAddressInvalid =>
      'Introduce una dirección HTTP o HTTPS con un host.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Esta página web solicitó una nueva ventana que no se puede abrir en este dispositivo.';

  @override
  String get schoolWebImportSecureConnection => 'Conexión segura';

  @override
  String get schoolWebImportInsecureConnection => 'Conexión no segura';

  @override
  String get schoolWebImportSignInConsentTitle =>
      '¿Abrir el inicio de sesión de la escuela?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'El inicio de sesión de la escuela puede enviar credenciales mediante formularios o redirecciones del servidor a la escuela y a sus proveedores de acceso. Android no puede pausar cada transferencia de este tipo para mostrar una confirmación independiente del destino. Continúa solo si confías en ellos para esta sesión de importación:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      '¿Abrir un inicio de sesión escolar no seguro?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Este inicio de sesión escolar usa HTTP. Cualquiera que pueda observar o alterar esta conexión podría leer o cambiar sus credenciales y el contenido de la página. Continúe solo si acepta este riesgo para:\n\n$origin';
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
