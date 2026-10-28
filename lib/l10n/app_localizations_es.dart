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
  String get schoolImportParseErrorMessage =>
      'No se pudo analizar el horario. Comprueba el contenido, la configuración del analizador y la conexión de red e inténtalo de nuevo.';

  @override
  String get schoolImportParsePageContinue => 'Continuar';

  @override
  String get schoolImportExpandWarnings => 'Mostrar avisos de importación';

  @override
  String get schoolImportCollapseWarnings => 'Ocultar avisos de importación';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Algunos cursos llegan hasta la semana $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      '¿Reemplazar el horario actual?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'El horario importado reemplazará al horario actual.';

  @override
  String get createTimetable => 'Nuevo horario';

  @override
  String get jumpToWeek => 'Ir a la semana';

  @override
  String get timetable => 'Horario';

  @override
  String get themeWorkspaceSchedule => 'Agenda';

  @override
  String get timetableName => 'Nombre del horario';

  @override
  String get timetableNameRequired => 'Introduce el nombre del horario';

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
  String get customFieldsInvalidJson =>
      'Introduce un objeto JSON válido o borra el contenido del campo.';

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
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsSectionWorkspace => 'Espacio de trabajo';

  @override
  String get settingsSectionAbout => 'Acerca de Sked';

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
  String get timetableHorizontalLayoutSection => 'Diseño horizontal y gestos';

  @override
  String get fitDaySelectorToWidth =>
      'Ajustar el selector de días a la pantalla';

  @override
  String get fitDaySelectorToWidthHint =>
      'Muestra los siete días en pantalla cuando sea posible. Desactiva esta opción para usar un ancho fijo y desplazarte.';

  @override
  String get fitWeekColumnsToWidth =>
      'Ajustar las columnas semanales a la pantalla';

  @override
  String get enableWeekSwipeNavigation => 'Deslizar para cambiar de semana';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Desliza a izquierda o derecha para cambiar de semana. Si usas anchos fijos, arrastra primero más allá del borde.';

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
  String get includePrereleaseUpdates => 'Recibir versiones preliminares';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Incluir versiones Alpha, Beta y RC, que pueden ser inestables. Si se desactiva, solo se ofrecen versiones estables.';

  @override
  String get currentVersionLabel => 'Versión actual';

  @override
  String get newVersionAvailable => 'Actualización disponible';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get ignoreThisVersion => 'Ignorar esta versión';

  @override
  String get openUpdatesFailed => 'No se pudo abrir el enlace de actualización';

  @override
  String get updateCheckFailedTitle =>
      'Falló la comprobación de actualizaciones';

  @override
  String get githubRepository => 'Repositorio de GitHub';

  @override
  String get googlePlayStoreDesc => 'Ver Sked en Google Play';

  @override
  String get openGooglePlayFailed => 'No se pudo abrir Google Play';

  @override
  String get microsoftStoreDesc => 'Ver Sked en Microsoft Store';

  @override
  String get openMicrosoftStoreFailed => 'No se pudo abrir Microsoft Store';

  @override
  String get starSkedOnGithub => '¡Dale una estrella a Sked en GitHub!';

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
  String get studentDayEmpty => 'No hay clases este día';

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
  String get periodTimesUnsavedExitTitle => 'Cambios sin guardar';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'No se pudieron guardar los últimos cambios en los horarios de los periodos. Puedes reintentar, seguir editando o descartarlos.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Algunos horarios de periodos no son válidos. Corrígelos antes de guardar o descarta los cambios y sal.';

  @override
  String get discardChangesAndExit => 'Descartar y salir';

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
      'Sked es una herramienta de horarios que prioriza el almacenamiento local. Los horarios de clases, las agendas generales, los conjuntos de horas de clase y la configuración de sitios escolares se guardan solo en tu dispositivo o navegador y nunca se suben automáticamente. La aplicación solo procesa datos cuando activas expresamente acciones como importar, analizar texto / HTML de horarios, importar páginas web escolares, compartir o abrir enlaces externos. La política de privacidad completa está disponible en línea.';

  @override
  String get privacyGateTitle =>
      'Acepta la política de privacidad antes de usar la app';

  @override
  String get privacyGateSummaryStorage =>
      'Los horarios de clases, las agendas generales, los conjuntos de horas de clase y la configuración de sitios escolares solo se guardan localmente y no se suben automáticamente a un servidor del desarrollador.';

  @override
  String get privacyGateSummaryImportExport =>
      'La importación, la exportación, las copias de seguridad completas y el uso compartido solo se realizan cuando los inicias expresamente. Las copias completas de la aplicación excluyen las claves API personalizadas, y el análisis de texto / HTML de horarios solo envía el contenido presentado al punto de acceso del analizador que has configurado.';

  @override
  String get privacyGateSummaryUpdates =>
      'Si una versión posterior cambia la forma en que se manejan los datos, la app puede pedirte que revises la política de privacidad actualizada de nuevo.';

  @override
  String get schoolWebImportEntry => 'Importar desde página web escolar';

  @override
  String get schoolWebImportEntryDesc =>
      'Importa la página actual del horario desde el sitio escolar.';

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
  String get schoolSitesImportPreviewTitle =>
      'Revisar la importación de sitios escolares';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount sitios válidos, $invalidCount entradas no válidas.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'El archivo contiene una lista vacía de sitios escolares.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'La entrada $position no es válida y se omitirá.';
  }

  @override
  String get schoolSitesImportMerge => 'Combinar';

  @override
  String get schoolSitesImportReplace => 'Reemplazar';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      '¿Reemplazar los sitios escolares actuales?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Se eliminarán los $currentCount sitios actuales y se guardarán $importedCount sitios importados. Esta acción no se puede deshacer.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Los datos de sitios escolares necesitan recuperación';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked no pudo leer el archivo de sitios escolares ni su copia de seguridad. Se crearon copias protegidas antes de bloquear las escrituras.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'El almacenamiento de sitios escolares no está disponible';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked no puede acceder al almacenamiento de sitios escolares ahora. Comprueba el acceso al almacenamiento y la disponibilidad del dispositivo y reintenta. No se sobrescribirán los datos actuales de los sitios.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Los archivos de recuperación y las ubicaciones de almacenamiento afectadas se muestran a continuación. No modifiques ningún archivo hasta recuperar la lista de sitios.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Empezar sin sitios escolares';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      '¿Empezar con una lista vacía de sitios escolares?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Se conservarán las copias protegidas, pero Sked creará un archivo vacío de sitios escolares. Continúa solo si no quieres reintentar la recuperación primero.';

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
  String get schoolWebImportUnsupportedPlatform =>
      'Esta plataforma aún no admite el inicio de sesión web incrustado. Usa una plataforma con compatibilidad con WebView.';

  @override
  String get schoolWebImportNoSchools =>
      'No hay ninguna configuración de escuela disponible. Revisa primero school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'No se pudo cargar la configuración del centro. Inténtalo de nuevo.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importar la página actual';

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
  String get schoolImportParserSettingsTitle => 'API para importar horarios';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configura la API compatible con OpenAI para importar horarios, no para un asistente de chat.';

  @override
  String get schoolImportParserSourceTitle => 'Fuente del analizador';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Compatible con OpenAI personalizado';

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
  String get schoolImportParserBaseUrl => 'URL base';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'La Base URL debe ser una URL HTTP o HTTPS con host.';

  @override
  String get schoolImportParserApiKey => 'Clave API';

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
      'La clave API personalizada se almacena mediante el sistema de almacenamiento seguro de la plataforma cuando está disponible. Usa credenciales del analizador personalizado y puntos de acceso HTTP solo en dispositivos, navegadores y redes de confianza.';

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
  String get clearAppData => 'Borrar datos';

  @override
  String get clearAppDataDesc =>
      'Eliminar permanentemente todos los datos locales de Sked y cerrar la aplicación';

  @override
  String get clearAppDataConfirmTitle => '¿Borrar todos los datos de Sked?';

  @override
  String get clearAppDataConfirmMessage =>
      'Esto elimina permanentemente horarios, agendas, ajustes, sitios escolares, copias de seguridad locales, copias de recuperación y la clave API de IA, y después cierra Sked. Los archivos exportados a otras ubicaciones no se eliminan. Esta acción no se puede deshacer.';

  @override
  String get clearAppDataAction => 'Borrar datos y salir';

  @override
  String get clearAppDataFailed =>
      'No se pudieron borrar todos los datos locales. Sked permanecerá abierto para que puedas reintentar.';

  @override
  String get clearAppDataExitFailed =>
      'Se borraron los datos locales, pero Sked no pudo cerrarse. Cierra la aplicación manualmente antes de volver a usarla.';

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
      'El horario seleccionado no está disponible. Selecciona un horario de nuevo.';

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
  String get generalSchedule => 'Agenda';

  @override
  String get studentTimetable => 'Horario';

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
  String get firstLaunchPrivacyConsentBefore =>
      'Al elegir un espacio de trabajo inicial, confirmas que has leído y aceptas la ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Política de privacidad';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Cambiar de modo';

  @override
  String get switchToStudentTimetable => 'Cambiar al horario';

  @override
  String get today => 'Hoy';

  @override
  String get addEvent => 'Añadir evento';

  @override
  String get editEvent => 'Editar evento';

  @override
  String get eventTitle => 'Título';

  @override
  String get eventTitleRequired => 'Introduce un título';

  @override
  String get eventStartTime => 'Hora de inicio';

  @override
  String get eventEndTime => 'Hora de fin';

  @override
  String get eventDate => 'Fecha';

  @override
  String get eventTime => 'Hora';

  @override
  String get eventNotes => 'Notas';

  @override
  String get eventColor => 'Color';

  @override
  String get eventRecurrence => 'Repetir';

  @override
  String get recurrenceNone => 'No se repite';

  @override
  String get recurrenceWeekly => 'Semanal';

  @override
  String get recurrenceEndDate => 'Fecha de fin';

  @override
  String get repeatsWeekly => 'Se repite cada semana';

  @override
  String recurrenceUntil(Object date) {
    return 'Hasta $date';
  }

  @override
  String get switchToGeneralSchedule => 'Cambiar a la agenda';

  @override
  String get generalDisplaySettings => 'Ajustes generales de visualización';

  @override
  String get generalDisplaySettingsDesc =>
      'Vistas, barra de herramientas, formato de fecha y adición rápida';

  @override
  String get closePopupOnOutsideTap =>
      'Cerrar la ventana emergente al tocar fuera';

  @override
  String get showGridLines => 'Mostrar líneas de la cuadrícula';

  @override
  String get generalScheduleImportExport => 'Importar y exportar categorías';

  @override
  String get generalScheduleImportExportDesc =>
      'Importar o compartir categorías de la agenda';

  @override
  String get importGeneralSchedules => 'Importar categorías';

  @override
  String get importGeneralSchedulesDesc => 'Leer categorías de un archivo JSON';

  @override
  String get shareGeneralSchedules => 'Compartir categorías';

  @override
  String get shareGeneralSchedulesDesc =>
      'Compartir categorías como archivo JSON';

  @override
  String get saveGeneralSchedules => 'Guardar categorías';

  @override
  String get saveGeneralSchedulesDesc => 'Guardar categorías como archivo JSON';

  @override
  String get selectSchedulesToExport => 'Seleccionar categorías para exportar';

  @override
  String get selectSchedulesToImport => 'Seleccionar categorías para importar';

  @override
  String generalScheduleEventCount(int count) {
    return 'Eventos: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Se importaron $count categorías';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      '¿Añadir lo importado como nueva categoría o reemplazar una existente?';

  @override
  String get addAsNewSchedule => 'Añadir como nueva categoría';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Selecciona al menos una categoría.';

  @override
  String get noExportableScheduleMessage =>
      'No hay categorías disponibles para exportar.';

  @override
  String get noSchedulesInImportMessage =>
      'El archivo importado no contiene categorías.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Elige exactamente una categoría importada para el reemplazo.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'La categoría seleccionada para reemplazar no está disponible.';

  @override
  String get calendars => 'Categorías';

  @override
  String get calendar => 'Categoría';

  @override
  String get viewWeek => 'Semana';

  @override
  String get viewDay => 'Día';

  @override
  String get viewList => 'Lista';

  @override
  String get viewMonth => 'Mes';

  @override
  String visibleCategoryCount(int count) {
    return '$count categorías';
  }

  @override
  String get noVisibleCategories => 'No hay categorías visibles';

  @override
  String get selectCategoryToReplace => 'Elegir categoría para reemplazar';

  @override
  String get replaceCategory => 'Reemplazar categoría';

  @override
  String get deleteEventTitle => 'Eliminar evento';

  @override
  String get deleteEventConfirmation =>
      'Este evento se eliminará permanentemente.';

  @override
  String get deleteRecurringEventTitle => 'Eliminar evento recurrente';

  @override
  String get eventDuplicated => 'Evento duplicado';

  @override
  String get allDay => 'Todo el día';

  @override
  String get collapseAllDayTimeline => 'Contraer eventos de todo el día';

  @override
  String get expandAllDayTimeline => 'Expandir eventos de todo el día';

  @override
  String allDayEventsCount(int count) {
    return '$count eventos de todo el día';
  }

  @override
  String moreEvents(int count) {
    return '+$count más';
  }

  @override
  String get noMatchingEvents => 'No hay eventos que coincidan';

  @override
  String get noUpcomingEvents => 'No hay eventos próximos';

  @override
  String get addCalendar => 'Añadir categoría';

  @override
  String get newCalendar => 'Nueva categoría';

  @override
  String get hideCalendar => 'Ocultar categoría';

  @override
  String get showCalendar => 'Mostrar categoría';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get renameCalendar => 'Cambiar nombre de categoría';

  @override
  String get name => 'Nombre';

  @override
  String get deleteCalendar => 'Eliminar categoría';

  @override
  String deleteCalendarMessage(Object name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get deleteThisOccurrence => 'Eliminar esta ocurrencia';

  @override
  String get deleteFutureOccurrences => 'Eliminar esta y las siguientes';

  @override
  String get deleteAllOccurrences => 'Eliminar toda la serie';

  @override
  String get duplicateEvent => 'Duplicar';

  @override
  String get repeatsDaily => 'Se repite cada día';

  @override
  String get repeatsMonthly => 'Se repite cada mes';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Se repite cada $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count veces';
  }

  @override
  String get recurrenceDaily => 'Diaria';

  @override
  String get recurrenceMonthly => 'Mensual';

  @override
  String get recurrenceCustom => 'Personalizada';

  @override
  String get recurrenceEvery => 'Cada';

  @override
  String get recurrenceUnit => 'Unidad';

  @override
  String get recurrenceDays => 'Días';

  @override
  String get recurrenceWeeks => 'Semanas';

  @override
  String get recurrenceMonths => 'Meses';

  @override
  String get recurrenceRepeatCount => 'Número de repeticiones';

  @override
  String get recurrenceNoLimit => 'Sin límite';

  @override
  String get recurrencePositiveNumber => 'Introduce un número positivo';

  @override
  String get clearEndDate => 'Borrar fecha de fin';

  @override
  String get pickDate => 'Elegir fecha';

  @override
  String get pickTime => 'Elegir hora';

  @override
  String get reminder => 'Recordatorio';

  @override
  String get reminderAtStart => 'Al inicio';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min antes';
  }

  @override
  String get reminderHourBefore => '1 hora antes';

  @override
  String get reminderDayBefore => '1 día antes';

  @override
  String get markReminderHandled => 'Marcar como atendido';

  @override
  String get restoreReminder => 'Restablecer el recordatorio en la aplicación';

  @override
  String get reminderHandled =>
      'Recordatorio en la aplicación marcado como atendido';

  @override
  String get reminderRestored => 'Recordatorio en la aplicación restablecido';

  @override
  String get reminderUpcoming => 'Próximos';

  @override
  String get generalFitWeekColumnsToWidth => 'Ajustar la semana a la pantalla';

  @override
  String get showWeekends => 'Mostrar fines de semana';

  @override
  String get startHour => 'Hora inicial';

  @override
  String get endHour => 'Hora final';

  @override
  String get timeGridDensity => 'Densidad de la cuadrícula horaria';

  @override
  String get timeGridHourHeight => 'Altura de las filas horarias';

  @override
  String get timeGridHourHeightHint =>
      'Ajusta la escala vertical de las vistas diaria y semanal sin cambiar el intervalo de 15, 30 o 60 minutos de la cuadrícula.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Importar archivo JSON';

  @override
  String get pasteJson => 'Pegar JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Importar categorías desde JSON copiado';

  @override
  String get importIcsFile => 'Importar archivo ICS';

  @override
  String get importIcsFileDesc =>
      'Leer eventos de un archivo de calendario .ics';

  @override
  String get pasteIcs => 'Pegar ICS';

  @override
  String get pasteIcsDesc =>
      'Importar eventos desde texto de calendario copiado';

  @override
  String get copyJson => 'Copiar JSON';

  @override
  String get copyJsonDesc => 'Copiar categorías seleccionadas como texto JSON';

  @override
  String get shareIcs => 'Compartir ICS';

  @override
  String get shareIcsDesc => 'Compartir calendarios seleccionados como .ics';

  @override
  String get saveIcs => 'Guardar ICS';

  @override
  String get saveIcsDesc => 'Guardar calendarios seleccionados como .ics';

  @override
  String get copyIcs => 'Copiar ICS';

  @override
  String get copyIcsDesc => 'Copiar calendarios seleccionados como texto ICS';

  @override
  String get importIcs => 'Importar ICS';

  @override
  String get icsContent => 'Contenido ICS';

  @override
  String get pasteIcsContentHint =>
      'Pega aquí el contenido que empieza con BEGIN:VCALENDAR';

  @override
  String get icsReminderExportTitle =>
      'La exportación ICS no incluye recordatorios';

  @override
  String get icsReminderExportMessage =>
      'Los recordatorios no se incluyen en el ICS exportado. Elige JSON para conservar la configuración de los recordatorios.';

  @override
  String get icsReminderExportJsonAction => 'Exportar JSON';

  @override
  String get icsReminderExportContinueAction => 'Continuar con ICS';

  @override
  String get icsReminderImportNotice =>
      'Los eventos importados desde ICS tendrán los recordatorios desactivados. Usa JSON para restaurar la configuración de los recordatorios.';

  @override
  String get icsReminderReplaceTitle => '¿Reemplazar eventos y recordatorios?';

  @override
  String icsReminderReplaceMessage(String calendar) {
    return 'Al reemplazar «$calendar» con eventos de ICS, se sobrescribirán sus eventos y se desactivarán sus recordatorios. Cancela para exportar primero una copia de seguridad JSON, o vuelve atrás y añade una categoría nueva.';
  }

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Se encontraron $count eventos. ¿Añadirlos como nueva categoría o reemplazar una existente?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Se importaron $count categorías con $warningCount avisos';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Se omitió un evento sin hora de inicio.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Se omitió un evento con una hora de inicio no compatible.';

  @override
  String get importWarningAdjustedEnd =>
      'Se ajustó un evento cuya hora de fin no era posterior a la de inicio.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Se ignoraron campos ICS no compatibles: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Se ignoró la frecuencia de repetición no compatible: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Seleccionar calendarios para copiar como ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Seleccionar calendarios para exportar como ICS';

  @override
  String get exportIcsText => 'Exportar texto ICS';

  @override
  String get exportJsonText => 'Exportar texto JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Se restauraron los datos de la aplicación desde la copia de seguridad anterior porque no se pudo cargar el archivo principal.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'El archivo principal de datos y su copia de seguridad están dañados. La aplicación está usando un estado inicial.';

  @override
  String get dataRecoveryCorruptTitle => 'Tus datos necesitan recuperación';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked no pudo leer el archivo principal de datos ni su copia de seguridad. Se crearon copias protegidas antes de bloquear las escrituras.';

  @override
  String get dataRecoveryIoFailureTitle =>
      'El almacenamiento no está disponible';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked no puede acceder al almacenamiento local ahora. Comprueba el acceso al almacenamiento y la disponibilidad del dispositivo y reintenta. No se sobrescribirán los datos existentes.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Actualiza Sked para abrir estos datos';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Estos datos se crearon con una versión más reciente de Sked. Actualiza la aplicación antes de reintentar. Empezar de cero está desactivado para protegerlos.';

  @override
  String get dataRecoveryRetryAction => 'Reintentar';

  @override
  String get dataRecoveryArtifactsHint =>
      'Los archivos de recuperación y las ubicaciones de almacenamiento afectadas se muestran a continuación. No modifiques ningún archivo hasta recuperar tus datos.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Mostrar archivos y ubicaciones de recuperación';

  @override
  String get dataRecoveryStartFreshAction => 'Empezar con datos nuevos';

  @override
  String get dataRecoveryStartFreshConfirmTitle => '¿Empezar con datos nuevos?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Se conservarán las copias protegidas, pero Sked creará un archivo local de datos nuevo. Continúa solo si no quieres reintentar la recuperación primero.';

  @override
  String get previousMonth => 'Mes anterior';

  @override
  String get nextMonth => 'Mes siguiente';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'En curso';

  @override
  String get deleteCourseTitle => 'Eliminar curso';

  @override
  String get deleteCourseMessage => '¿Eliminar este curso?';

  @override
  String get showLunarCalendar => 'Mostrar calendario lunar';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count eventos';
  }

  @override
  String get defaultView => 'Vista predeterminada';

  @override
  String get generalDefaultViewSection => 'Al iniciar';

  @override
  String get generalViewSwitchBehavior => 'Botón de cambio de vista';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Ocultar navegación entre espacios de trabajo';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Oculta la navegación entre espacios. Puedes cambiar de espacio desde el menú de la pantalla principal.';

  @override
  String get generalDateLabelFormat => 'Formato de la fecha';

  @override
  String get generalDateLabelFormatLocalized => 'Localizado (jul. 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Barras (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Diseño de la barra de herramientas';

  @override
  String get toolbarNavigationSection =>
      'Navegación de la barra de herramientas';

  @override
  String get toolbarNavigationHiddenBehavior => 'Elementos ocultos';

  @override
  String get toolbarNavigationRemove => 'Ocultar por completo';

  @override
  String get toolbarNavigationMore => 'Mover a Más';

  @override
  String get toolbarNavigationReorder =>
      'Reordenar elementos de la barra de herramientas';

  @override
  String get toolbarNavigationVisibility =>
      'Mostrar elemento de la barra de herramientas';

  @override
  String get toolbarNavigationTimetable => 'Selector de horario';

  @override
  String get toolbarNavigationWeek => 'Selector de semana';

  @override
  String get toolbarNavigationView => 'Selector de vista';

  @override
  String get toolbarNavigationCategory => 'Selector de categoría';

  @override
  String get toolbarNavigationDate => 'Selector de fecha';

  @override
  String get generalToolbarWidthPolicy =>
      'Distribución del espacio de la barra de herramientas';

  @override
  String get generalToolbarWidthContent => 'Distribución automática';

  @override
  String get generalToolbarWidthBalanced => 'Equilibrada';

  @override
  String get generalToolbarWidthCalendarPriority => 'Prioridad de categoría';

  @override
  String get generalToolbarWidthDatePriority => 'Prioridad de fecha';

  @override
  String get generalViewSwitchCycle => 'Alternar entre vistas';

  @override
  String get generalViewSwitchMenu => 'Abrir menú de vistas';

  @override
  String get generalViewSwitchTooltip => 'Cambiar vista';

  @override
  String get generalViewSwitchMenuTooltip => 'Elegir vista';

  @override
  String get generalViewLongPressTodayHint => 'Mantén pulsado para ir a hoy';

  @override
  String get generalScheduleDisplaySection => 'Visualización de la agenda';

  @override
  String get generalTimeGridSection => 'Cuadrícula horaria';

  @override
  String get generalPopupSection => 'Comportamiento de las ventanas emergentes';

  @override
  String get quickActionsSection => 'Acciones rápidas';

  @override
  String get showAddCourseFab => 'Mostrar botón flotante para añadir cursos';

  @override
  String get showAddCourseFabHint =>
      'Muestra u oculta el botón flotante para añadir cursos en la esquina inferior derecha del horario.';

  @override
  String get showAddEventFab => 'Mostrar botón flotante para añadir eventos';

  @override
  String get showAddEventFabHint =>
      'Muestra u oculta el botón flotante para añadir eventos en la esquina inferior derecha de la agenda.';

  @override
  String get enableLongPressAddCourse =>
      'Mantener pulsada una zona vacía para añadir cursos';

  @override
  String get enableLongPressAddCourseHint =>
      'Mantén pulsada una zona vacía de la cuadrícula del horario para añadir un curso.';

  @override
  String get enableLongPressAddEvent =>
      'Mantener pulsada una zona vacía para añadir eventos';

  @override
  String get enableLongPressAddEventHint =>
      'En la vista diaria o semanal, mantén pulsada una zona vacía de la cuadrícula horaria para añadir un evento.';

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
  String get developerNotificationDiagnostics =>
      'Diagnóstico de notificaciones';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Comprueba el estado de entrega de Android, reconstruye el plan de recordatorios y envía notificaciones de prueba seguras mediante el servicio habitual de Sked.';

  @override
  String get developerNotificationUnsupported =>
      'El diagnóstico de notificaciones solo está disponible en Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'El diagnóstico estará disponible cuando se inicie el coordinador de la agenda.';

  @override
  String get developerNotificationRefresh => 'Actualizar diagnóstico';

  @override
  String get developerNotificationSystemStatus =>
      'Permiso de notificaciones del sistema';

  @override
  String get developerNotificationPermissionAllowed => 'Permitido';

  @override
  String get developerNotificationPermissionBlocked => 'Bloqueado';

  @override
  String get developerNotificationExactAlarm => 'Alarmas exactas';

  @override
  String get developerNotificationExactAlarmAllowed => 'Permitidas';

  @override
  String get developerNotificationExactAlarmBlocked => 'No permitidas';

  @override
  String get developerNotificationPlan => 'Plan de notificaciones de la agenda';

  @override
  String get developerNotificationCoverage => 'Cobertura de recordatorios';

  @override
  String get developerNotificationCoverageReady =>
      'Todos los recordatorios finitos conocidos están programados directamente';

  @override
  String get developerNotificationCoverageRenewable =>
      'Los recordatorios recurrentes se reprograman a largo plazo en la medida de lo posible';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'La capacidad de alarmas directas está llena; los recordatorios posteriores se reprograman en la medida de lo posible';

  @override
  String get developerNotificationCoverageBlocked =>
      'No se cumplen las condiciones para una entrega precisa';

  @override
  String get developerNotificationCoverageFailed =>
      'Falló la última sincronización de recordatorios';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled alarmas directas / capacidad: $capacity';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Último error: $message';
  }

  @override
  String get developerNotificationTestChannel => 'Canal de prueba';

  @override
  String get developerNotificationTestCourse => 'Recordatorios de cursos';

  @override
  String get developerNotificationTestSchedule => 'Recordatorios de eventos';

  @override
  String get developerNotificationImmediateTest => 'Enviar prueba inmediata';

  @override
  String get developerNotificationThirtySecondTest =>
      'Programar prueba en segundo plano en 30 segundos';

  @override
  String get developerNotificationImmediateQueued =>
      'Notificación de prueba inmediata enviada.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Prueba en segundo plano programada en 30 segundos.';

  @override
  String get developerNotificationAppSwitch =>
      'Interruptor de recordatorios de la aplicación';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Activado para los recordatorios habituales';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Desactivado para los recordatorios habituales; las pruebas de desarrollo siguen disponibles';

  @override
  String get developerNotificationTimeZone => 'Zona horaria local';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Aún no se ha creado. Una prueba de desarrollo lo creará.';

  @override
  String get developerNotificationChannelEnabledState => 'Activado';

  @override
  String get developerNotificationChannelBlockedState => 'Bloqueado';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Importancia: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Importancia no disponible';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending pendientes / $active activas';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Última notificación nativa: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Aún no se ha registrado ninguna reconciliación.';

  @override
  String get developerNotificationNextReminder => 'Próximo recordatorio real';

  @override
  String get developerNotificationNoPendingReminder =>
      'No hay recordatorios futuros en el plan actual';

  @override
  String get developerNotificationNextRenewal =>
      'Próxima reprogramación no garantizada';

  @override
  String get developerNotificationLastSynchronization =>
      'Última sincronización de recordatorios';

  @override
  String get developerNotificationLateRecovery =>
      'Recuperación de recordatorios atrasados';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return 'Se recuperaron $count recordatorios después de su hora original';
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
  String get developerNotificationReconcileOriginForeground => 'Primer plano';

  @override
  String get developerNotificationReconcileOriginBackground => 'Segundo plano';

  @override
  String get developerNotificationReconcileModeAuthoritative => 'Autoritativa';

  @override
  String get developerNotificationReconcileModeRecovery => 'Recuperación';

  @override
  String get developerNotificationRunRecovery =>
      'Ejecutar recuperación de recordatorios';

  @override
  String get developerNotificationRecoveryComplete =>
      'Recuperación de recordatorios completada';

  @override
  String get developerNotificationReconcileResultSuccess => 'Correcto';

  @override
  String get developerNotificationReconcileResultSkipped => 'Omitido';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Bloqueado hasta que se cumplan todas las condiciones de entrega precisa';

  @override
  String get developerNotificationReconcileResultFailed => 'Fallido';

  @override
  String get developerNotificationBackgroundLimits =>
      'Límites de segundo plano del fabricante';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Las restricciones de segundo plano del fabricante pueden afectar a la entrega.';

  @override
  String get developerNotificationAutostart =>
      'Inicio en segundo plano del fabricante';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Fabricante: $vendor; hay un acceso a sus ajustes. Android no permite consultar el estado del permiso.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Fabricante: $vendor; se usarán los detalles de la aplicación como alternativa. Android no permite consultar el estado del permiso.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'No hay un acceso disponible a los ajustes de segundo plano del fabricante.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Último destino abierto: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'ajustes del fabricante';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'detalles de la aplicación';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'ninguno';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Límites de recuperación tras reiniciar';

  @override
  String get developerNotificationRebootBoundary =>
      'La recuperación comienza tras el primer desbloqueo; una aplicación detenida a la fuerza no puede iniciarse sola.';

  @override
  String get developerNotificationTestChecking =>
      'Las pruebas no están disponibles mientras se comprueba el estado de las notificaciones.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Las pruebas no están disponibles porque las notificaciones del sistema están bloqueadas.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Las pruebas no están disponibles porque el canal de notificación seleccionado está bloqueado.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Gestionado por los ajustes de notificaciones de Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'No se aplica en Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Identidad del paquete de Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Identidad MSIX disponible; se pueden retirar las notificaciones mostradas';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Instala la versión MSIX para retirar de forma fiable las notificaciones mostradas';

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
  String get notificationSettingsSection => 'Recordatorios y notificaciones';

  @override
  String get notificationCoverage => 'Cobertura de recordatorios';

  @override
  String get notificationCoverageBlocked =>
      'Reminders are blocked and will not fire. Review the system requirements below.';

  @override
  String get notificationCoverageFailed =>
      'Reminders could not be synced. Open notification settings and try again.';

  @override
  String get notificationCoverageRenewable =>
      'Los eventos recurrentes sin fecha de fin se reprograman en segundo plano para mantener la cobertura a largo plazo.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android puede programar directamente hasta $capacity recordatorios; se intenta reprogramar los posteriores con antelación.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Activar recordatorios y notificaciones';

  @override
  String get notificationSettingsEnabledHint =>
      'Solo programa elementos que tengan un recordatorio. Define más abajo un recordatorio predeterminado para los cursos que lo heredan.';

  @override
  String get notificationPrecisionLimitations =>
      'Los recordatorios dependen de los permisos y la ejecución en segundo plano. Apagados, cambios de hora o restricciones del sistema pueden retrasarlos.';

  @override
  String get notificationSettingsEnabledSummary => 'Activado';

  @override
  String get notificationSettingsDisabledSummary => 'Desactivado';

  @override
  String get notificationDefaultsSection => 'Recordatorios predeterminados';

  @override
  String get notificationCourseDefaultReminder =>
      'Recordatorio predeterminado de cursos';

  @override
  String get notificationGeneralDefaultReminder =>
      'Recordatorio predeterminado de eventos';

  @override
  String get notificationReminderOff => 'Sin recordatorio';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minutos antes';
  }

  @override
  String get notificationPermission => 'Permiso de notificaciones';

  @override
  String get notificationPermissionGranted => 'Permitido por el sistema';

  @override
  String get notificationPermissionDenied => 'Bloqueado por el sistema';

  @override
  String get notificationPermissionChecking => 'Comprobando permiso…';

  @override
  String get notificationPermissionRequest => 'Solicitar permiso';

  @override
  String get notificationPermissionOpenSettings => 'Abrir ajustes del sistema';

  @override
  String get notificationPermissionRequestFailed =>
      'No se pudo consultar el permiso de notificaciones. Reintenta.';

  @override
  String get notificationExactAlarm => 'Permiso de alarmas exactas';

  @override
  String get notificationExactAlarmAllowed => 'Permitido por el sistema';

  @override
  String get notificationExactAlarmRequired =>
      'Necesario para recordatorios a la hora exacta';

  @override
  String get notificationExactAlarmRequest => 'Permitir alarmas exactas';

  @override
  String get notificationBatteryOptimization => 'Optimización de batería';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Excluido de la optimización de batería de Android';

  @override
  String get notificationBatteryOptimizationWarning =>
      'Battery optimization or vendor background restrictions may delay reminders. You can adjust these in system settings.';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Abrir ajustes de optimización de batería';

  @override
  String get notificationAutostart => 'Inicio en segundo plano del fabricante';

  @override
  String get notificationAutostartVendorHint =>
      'Permite el inicio automático o la ejecución en segundo plano para restaurar los recordatorios después de reiniciar.';

  @override
  String get notificationAutostartFallbackHint =>
      'Abre los detalles de Sked y permite su ejecución en segundo plano. Android no puede verificar este ajuste del fabricante.';

  @override
  String get notificationAutostartUnavailable =>
      'No se encontró una página de ajustes del fabricante. Comprueba los detalles de Sked manualmente.';

  @override
  String get notificationAutostartRequest =>
      'Abrir ajustes de segundo plano del fabricante';

  @override
  String get notificationAutostartOpenFailed =>
      'No se pudieron abrir los ajustes de segundo plano del fabricante. Comprueba los detalles de Sked manualmente.';

  @override
  String get notificationLockScreenTitles =>
      'Mostrar títulos en las notificaciones';

  @override
  String get notificationLockScreenTitlesHint =>
      'También se aplica a la pantalla de bloqueo. Si se desactiva, solo se incluyen el tipo y la hora.';

  @override
  String get notificationPlatformUnsupported =>
      'Esta plataforma no ofrece notificaciones nativas.';

  @override
  String get workspaceFeatures => 'Gestión de funciones';

  @override
  String get workspaceBoth => 'Horario y agenda';

  @override
  String get workspaceOnlyStudent => 'Solo horario';

  @override
  String get workspaceOnlyGeneral => 'Solo agenda';

  @override
  String get workspaceDisableTitle => '¿Desactivar este espacio?';

  @override
  String get workspaceDisableMessage =>
      'Se conservarán los datos y las preferencias. Sus funciones y recordatorios se detendrán hasta que lo vuelvas a activar aquí.';

  @override
  String get workspaceEnableHint =>
      'Elige las funciones que utilizas. Al menos una debe permanecer activa.';

  @override
  String get workspaceLastRequired =>
      'Al menos un espacio debe permanecer activo.';

  @override
  String get workspaceReminderCleanupFailed =>
      'El espacio está desactivado, pero no se pudieron eliminar los recordatorios. Vuelve a intentar la recuperación de notificaciones.';

  @override
  String get settingsDataPrivacy => 'Datos y privacidad';

  @override
  String get selectedDayAgenda => 'Día seleccionado';

  @override
  String get notificationTroubleshooting => 'Permisos y solución de problemas';

  @override
  String get settingsConnection => 'Conexión';

  @override
  String get settingsAdvanced => 'Avanzado';

  @override
  String get unsavedChangesMessage =>
      'Tienes cambios sin guardar. ¿Descartarlos y salir?';

  @override
  String get backupWorkspaceSelection =>
      'La copia completa incluye los datos y la selección de espacios activados.';

  @override
  String get assistantLayoutPreview => 'IA · Vista previa del diseño';

  @override
  String get assistantSelectionContext =>
      'Usa la selección actual como contexto';

  @override
  String get assistantPreviewDescription =>
      'Discuss and work in the current workspace. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Borrador del mensaje';

  @override
  String get assistantPreviewNoSend =>
      'Solo es una vista previa del diseño. No se enviará ni cambiará nada.';

  @override
  String get resizePanel => 'Cambiar tamaño del panel';

  @override
  String get minimizeWindow => 'Minimizar';

  @override
  String get maximizeWindow => 'Maximizar';

  @override
  String get restoreWindow => 'Restaurar ventana';

  @override
  String get closeWindow => 'Cerrar ventana';

  @override
  String get courseSystemReminder => 'Recordatorio del sistema';

  @override
  String courseReminderInherit(String reminder) {
    return 'Usar predeterminado ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Los recordatorios del sistema están desactivados en los ajustes de notificaciones. Esta preferencia del curso se puede guardar de todos modos.';

  @override
  String get courseReminderDefaultOff =>
      'No hay un recordatorio predeterminado para los cursos. Elige uno personalizado aquí o define uno predeterminado en los ajustes de notificaciones.';

  @override
  String get courseReminderDeliveryHint =>
      'Esta preferencia se guarda con el curso. La entrega depende de los permisos de notificación del sistema y de las restricciones de segundo plano.';

  @override
  String get courseReminderPermissionUnknown =>
      'No se ha comprobado el estado de las notificaciones del sistema. Revisa los ajustes de notificaciones antes de confiar en los recordatorios.';

  @override
  String get courseReminderMinutesLabel => 'Minutos antes de la clase';

  @override
  String get exportAction => 'Exportar';

  @override
  String get datePickerSelectWeek => 'Seleccionar semana';

  @override
  String get datePickerSelectMonth => 'Seleccionar mes';

  @override
  String get generalDateLabelFormatDescription =>
      'Se aplica a la navegación por fechas en escritorio y pantallas pequeñas.';

  @override
  String get dateRangeTitle => 'Elegir intervalo de fechas';

  @override
  String get dateRangeCustom => 'Personalizado';

  @override
  String get dateRangeChooseStart => 'Elige la fecha de inicio';

  @override
  String get dateRangeChooseEnd => 'Elige la fecha de fin';

  @override
  String get dateRangeLimit =>
      'Selecciona entre 1 y 14 días, incluyendo ambos extremos.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return 'Personalizado · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Seleccionar con ruedas';

  @override
  String get courseReminderUseDefault => 'Usar predeterminado';

  @override
  String get courseReminderInvalidMinutes =>
      'Introduce un número entero de minutos, igual o mayor que cero.';

  @override
  String get generalCustomColumnWidth =>
      'Ancho de columnas en la vista personalizada';

  @override
  String get generalCustomColumnWidthAuto => 'Automático';

  @override
  String get generalCustomColumnWidthManual => 'Ancho mínimo';

  @override
  String get generalCustomColumnWidthMinimum => 'Ancho mínimo por día';

  @override
  String get generalCustomColumnWidthHint =>
      'Todas las fechas comparten este ancho mínimo. Las columnas llenan el espacio disponible o se desplazan horizontalmente. Solo afecta a la vista personalizada.';

  @override
  String get settingsAppearanceLanguage => 'Apariencia e idioma';

  @override
  String get settingsAppearanceDetails => 'Colores y contornos';

  @override
  String get monthNoEvents => 'No hay eventos este día';

  @override
  String get settingsOverview => 'Vista general';

  @override
  String get settingsThemeTarget => 'Tema para';

  @override
  String get settingsColorMode => 'Modo de color';

  @override
  String get settingsNotificationPreferences => 'Preferencias de recordatorios';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Recordatorios predeterminados, permisos y fiabilidad';

  @override
  String get settingsFeaturesSummary => 'Espacios de trabajo y navegación';

  @override
  String get settingsPrivacySummary =>
      'Política de privacidad y borrado de datos locales';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count periodos',
      one: '1 periodo',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Periodo';

  @override
  String get periodTimesDurationColumn => 'Duración';

  @override
  String get periodTimesGapColumn => 'Descanso';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Esperando para guardar…';

  @override
  String get periodTimesSaveFailed => 'Sin guardar · Error al guardar';

  @override
  String get periodTimesInvalidStatus =>
      'Sin guardar · Corrige los horarios señalados';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked no pudo confirmar si se revirtió el último guardado. Las escrituras están pausadas y se conservan las copias de recuperación. Revisa el almacenamiento y vuelve a cargar los datos.';

  @override
  String get settingsPanelDisplayMode => 'Visualización de paneles';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Compartida por horarios y agendas';

  @override
  String get settingsPanelDisplayOverlay => 'Superpuesto';

  @override
  String get settingsPanelDisplaySideBySide => 'En paralelo';

  @override
  String get settingsPanelDisplayAutomatic => 'Automático';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Se superpone a la derecha sin cambiar el tamaño del calendario.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Prioriza la vista en paralelo; se superpone solo si el calendario queda demasiado estrecho.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Usa la vista en paralelo si el calendario conserva un ancho legible; si no, se superpone.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Desactivar Ajustes o Espacio de trabajo en la barra de herramientas los mueve a Más en lugar de eliminarlos. Más no se puede ocultar mientras contenga acciones esenciales. El cambio de espacio de trabajo solo aparece cuando la navegación inferior está oculta y hay varios espacios de trabajo activados.';

  @override
  String get reminderEnded => 'Finalizado';

  @override
  String get reminderAutoCloseHint =>
      'Se cierra después de 10 segundos. Interactúa para mantenerlo abierto.';

  @override
  String get showReminderIndependently => 'Abrir por separado';

  @override
  String get categoryManagerTitle => 'Gestionar categorías';

  @override
  String get categoryHidden => 'Oculta';

  @override
  String get categoryShowOnCalendar => 'Mostrar en el calendario';

  @override
  String get categoryHideOnCalendar => 'Ocultar del calendario';

  @override
  String get categoryEditColor => 'Cambiar color de categoría';

  @override
  String get categoryThemePalette => 'Paleta del tema';

  @override
  String get categoryCustomColor => 'Personalizado';

  @override
  String get colorHexInvalid =>
      'Introduce un color hexadecimal de seis dígitos.';

  @override
  String get colorPickerHue => 'Tono';

  @override
  String get colorPickerSaturation => 'Saturación';

  @override
  String get colorPickerValue => 'Brillo';

  @override
  String get colorPickerHex => 'Color hexadecimal';

  @override
  String get colorPickerSpectrum => 'Espectro de colores';

  @override
  String get colorPickerSpectrumKeyboardHint =>
      'Usa las flechas izquierda y derecha para ajustar la saturación, y arriba y abajo para ajustar el brillo.';

  @override
  String categoryColorSlot(int number) {
    return 'Color del tema $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Las actualizaciones de la tienda pueden llegar más tarde. Su disponibilidad se indica en la página de la tienda.';

  @override
  String get storePrereleaseNotice =>
      'Recibir avisos de actualizaciones preliminares no te inscribe en un programa de pruebas de la tienda.';

  @override
  String get updateFoundTitle => 'Nueva versión disponible';

  @override
  String get updateNoNotes => 'No se proporcionaron notas de la versión.';

  @override
  String get updateLater => 'Más tarde';

  @override
  String get updateRetry => 'Reintentar';

  @override
  String get updatePrerelease => 'Versión preliminar';

  @override
  String get updateNetworkFailure =>
      'No se pudieron buscar actualizaciones. Comprueba la conexión y reintenta.';

  @override
  String updateNoNewerVersion(String version) {
    return 'No se encontró una versión más reciente (actual: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Restaurando copia de seguridad…';

  @override
  String get backupRestoreInProgressMessage =>
      'Podrás modificar los datos y los ajustes cuando termine la restauración. Puedes seguir consultándolos.';

  @override
  String get managePeriodTimeSets => 'Gestionar conjuntos de horarios de clase';

  @override
  String periodTimeSetUsageSummary(int periodCount, int timetableCount) {
    return 'Periodos: $periodCount · Horarios que lo usan: $timetableCount';
  }

  @override
  String chooseTimetableImportMethod(String name) {
    return 'Importa como un horario nuevo o reemplaza todos los datos y las clases de «$name».';
  }

  @override
  String get selectAtLeastOneWeek => 'Selecciona al menos una semana.';

  @override
  String get notificationRemindHiddenGeneralCalendars =>
      'Mantener los recordatorios de las categorías ocultas';

  @override
  String get notificationRemindHiddenGeneralCalendarsHint =>
      'Se aplica a los recordatorios de la aplicación y a las notificaciones del sistema. Estas últimas siguen dependiendo del interruptor de notificaciones.';

  @override
  String get generalReminderFollowDefault => 'Usar valor predeterminado';

  @override
  String get generalReminderCustom => 'Recordatorios personalizados';

  @override
  String get eventEditScopeTitle => 'Editar evento recurrente';

  @override
  String get eventEditThisOccurrence => 'Solo este evento';

  @override
  String get eventEditThisAndFollowing => 'Este y los siguientes eventos';

  @override
  String get eventEditEntireSeries => 'Toda la serie';

  @override
  String get eventEditEntireSeriesHint =>
      'Los cambios se aplican a toda la serie, incluidos los eventos pasados.';

  @override
  String get eventEditConflict =>
      'Este evento ha cambiado. Tu borrador se conserva; vuelve a abrir el evento para revisar la versión más reciente.';

  @override
  String eventSavedToHiddenCalendar(String name) {
    return 'Guardado en la categoría oculta «$name».';
  }

  @override
  String get viewEvent => 'Ver evento';

  @override
  String get schoolSitesNameRequired =>
      'Introduce el nombre del centro educativo.';

  @override
  String get schoolSitesLoginUrlRequired =>
      'Introduce una URL de inicio de sesión.';

  @override
  String get languageNoResults => 'No se encontraron idiomas coincidentes';

  @override
  String get themeGeneralMonthTextColors => 'Texto de la vista mensual';

  @override
  String get themeGeneralFestivalTextColor => 'Festividades y días festivos';

  @override
  String get themeGeneralSolarTermTextColor => 'Periodos solares';

  @override
  String get themeGeneralLunarTextColor => 'Fechas lunares';

  @override
  String get courseTextLowContrastHint =>
      'Este color de texto puede ser difícil de leer en algunas tarjetas de cursos (contraste inferior a 4.5:1). Puedes conservarlo o elegir otro.';

  @override
  String get shortenSemesterTitle => '¿Acortar el semestre?';

  @override
  String shortenSemesterMessage(int weeks, int count) {
    return 'El semestre terminará en la semana $weeks. Cursos con clases posteriores: $count. Se conservarán los cursos y las semanas elegidas. Restaura el número de semanas para volver a verlos.';
  }

  @override
  String get defaultGeneralCalendarName => 'Mi calendario';

  @override
  String get icsImportReportTitle => 'Informe de importación';

  @override
  String get icsImportReportAction => 'Ver informe';

  @override
  String get icsExportFailureTitle => 'No se puede exportar como ICS';

  @override
  String get icsCopyDiagnosticsAction => 'Copiar detalles';

  @override
  String get icsUnsupportedTimeZoneMessage =>
      'Este ICS contiene zonas horarias con nombre que Sked no puede interpretar de forma segura. No se ha importado nada. Exporta UTC u horas locales sin zona horaria desde el calendario de origen e inténtalo de nuevo.';

  @override
  String get icsExportMonthlyAnchorMismatchMessage =>
      'Este evento mensual no se puede representar con precisión en ICS. Exporta JSON para conservar sus fechas.';

  @override
  String get icsExportEmptyRecurrenceMessage =>
      'Este evento recurrente no tiene ocurrencias válidas para exportar como ICS. Exporta JSON para conservar el registro.';

  @override
  String get icsImportedCalendarName => 'Calendario importado';

  @override
  String get icsUntitledEventName => 'Evento sin título';

  @override
  String notificationWindowsCoverageLimit(int days, int capacity) {
    return 'Windows solo programa recordatorios para los próximos $days días, hasta $capacity a la vez. Vuelve a abrir la aplicación periódicamente para actualizar el plan.';
  }

  @override
  String notificationWindowsCoverageSummary(int count, String date) {
    return 'Recordatorios programados: $count. La última comprobación abarca hasta $date.';
  }

  @override
  String get notificationWindowsCoverageCapacityLimited =>
      'Se ha alcanzado el límite de recordatorios. Algunos aún no están programados. Vuelve a abrir la aplicación después de que se activen los próximos recordatorios para actualizar el plan.';

  @override
  String get courseInactiveThisWeek => 'No programado esta semana';

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
  String get notificationSnoozeAction => 'Posponer 10 minutos';

  @override
  String get notificationHandledAction => 'Marcar como gestionado';

  @override
  String get developerTestNotificationTitle =>
      'Prueba de notificaciones de Sked';

  @override
  String get developerTestNotificationCourseBody =>
      'El canal de recordatorios de cursos funciona.';

  @override
  String get developerTestNotificationScheduleBody =>
      'El canal de recordatorios de eventos funciona.';

  @override
  String get eventRecurrenceExceptionsChangeTitle => 'Change repeat pattern?';

  @override
  String get eventRecurrenceExceptionsChangeMessage =>
      'Previously skipped dates stay skipped only if the new repeat pattern still has an occurrence on that date. Other skip records will be removed. Turning repeats off removes all skip records. Events edited separately stay unchanged.';
}
