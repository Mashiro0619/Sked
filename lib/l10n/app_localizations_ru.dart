// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Неделя $week';
  }

  @override
  String get addCourse => 'Добавить занятие';

  @override
  String get settings => 'Настройки';

  @override
  String get multiTimetableSwitch => 'Переключить расписания';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Текущее расписание · $weeks нед.';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Нажмите для переключения · $weeks нед.';
  }

  @override
  String get editTimetable => 'Редактировать расписание';

  @override
  String get createTimetable => 'Новое расписание';

  @override
  String get jumpToWeek => 'Перейти к неделе';

  @override
  String get timetable => 'Расписание';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Название расписания';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Всего недель';

  @override
  String get delete => 'Удалить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get deleteTimetableTitle => 'Удалить расписание';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Удалить \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Расписания пока нет';

  @override
  String get noTimetableMessage =>
      'Создайте расписание или импортируйте его из JSON-файла.';

  @override
  String get importTimetable => 'Импортировать расписание';

  @override
  String get courseName => 'Название предмета';

  @override
  String get location => 'Место';

  @override
  String get dayOfWeek => 'День';

  @override
  String get semesterWeeks => 'Недели';

  @override
  String get startTime => 'Время начала';

  @override
  String get endTime => 'Время окончания';

  @override
  String get linkedPeriods => 'Связанные пары';

  @override
  String get linkedPeriodsUnmatched =>
      'Для текущего времени пары не найдены. Нажмите, чтобы выбрать вручную.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Пара $start-$end';
  }

  @override
  String get teacherName => 'Преподаватель';

  @override
  String get credits => 'Кредиты';

  @override
  String get remarks => 'Примечания';

  @override
  String get customFields => 'Пользовательские поля';

  @override
  String get customFieldsHint => 'По одному в строке, формат: ключ:значение';

  @override
  String get more => 'Ещё';

  @override
  String get selectDayOfWeek => 'Выберите день';

  @override
  String get selectSemesterWeeks => 'Выберите недели';

  @override
  String get selectAll => 'Выбрать все';

  @override
  String get clear => 'Очистить';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get selectLinkedPeriods => 'Выберите связанные пары';

  @override
  String get addCourseTitle => 'Добавить занятие';

  @override
  String get editCourseTitle => 'Редактировать занятие';

  @override
  String get editCourseTooltip => 'Редактировать занятие';

  @override
  String get place => 'Место';

  @override
  String get time => 'Время';

  @override
  String get notFilled => 'Не заполнено';

  @override
  String get none => 'Нет';

  @override
  String get conflictCourses => 'Конфликтующие занятия';

  @override
  String get locationNotFilled => 'Место не указано';

  @override
  String get setAsDisplayed => 'Сделать отображаемым';

  @override
  String get editThisCourse => 'Редактировать это занятие';

  @override
  String get settingsTitle => 'Настройки';

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
      'Для настройки сейчас нет доступного расписания.';

  @override
  String get semesterStartDate => 'Дата начала семестра';

  @override
  String get periodTimeSets => 'Набор времени пар';

  @override
  String get noPeriodTimeAvailable => 'Нет доступных наборов времени пар';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count пар';
  }

  @override
  String get coursePopupDismissSetting =>
      'Разрешить закрытие карточки занятия нажатием вне окна';

  @override
  String get coursePopupDismissSettingHint =>
      'При отключении также отключается закрытие свайпом вниз.';

  @override
  String get preserveTimetableGaps => 'Сохранять промежутки в расписании';

  @override
  String get preserveTimetableGapsHint =>
      'Если выключено, обеденные и другие перерывы будут скрыты, а последующие занятия поднимутся вверх.';

  @override
  String get showPastEndedCourses => 'Показывать завершившиеся занятия';

  @override
  String get showPastEndedCoursesHint =>
      'Показывать занятия, которые уже закончились к текущей реальной неделе, в более светло-сером стиле.';

  @override
  String get showFutureCourses => 'Показывать будущие занятия';

  @override
  String get showFutureCoursesHint =>
      'Показывать занятия, которые не активны на этой неделе, но появятся в следующих неделях, в сером стиле.';

  @override
  String get timetableDisplaySettings =>
      'Отображение и взаимодействие с расписанием';

  @override
  String get timetableDisplaySettingsDesc =>
      'Отображение занятий, макет, жесты смены недели и быстрое добавление';

  @override
  String get showTimetableGridLines => 'Показывать линии сетки расписания';

  @override
  String get showTimetableGridLinesHint =>
      'Управляет отображением горизонтальных и вертикальных линий сетки в расписании.';

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
  String get liveCourseOutlineColor => 'Цвет обводки занятия';

  @override
  String get liveCourseOutlineColorHint =>
      'Выберите, должна ли обводка применяться к текущему/следующему занятию или ко всем отображаемым занятиям на текущей странице.';

  @override
  String get liveCourseOutlineSettings => 'Обводка занятия';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Настройте включение обводки, цель применения, следование цвету темы и итоговый цвет обводки.';

  @override
  String get liveCourseOutlineEnabled => 'Включить обводку';

  @override
  String get liveCourseOutlineFollowTheme => 'Следовать цвету темы';

  @override
  String get liveCourseOutlineTarget => 'К чему применять обводку';

  @override
  String get liveCourseOutlineTargetCurrentOrNext =>
      'Текущее/следующее занятие';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Все отображаемые занятия';

  @override
  String get liveCourseOutlineEffectiveColor => 'Итоговый цвет';

  @override
  String get liveCourseOutlineCustomColor => 'Пользовательский цвет обводки';

  @override
  String get liveCourseOutlineWidth => 'Толщина обводки';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Язык';

  @override
  String get languagePageDescription =>
      'Выберите один из языков, которые действительно доступны в приложении.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Ответ API';

  @override
  String get theme => 'Тема';

  @override
  String get themeFollowSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeColor => 'Цвет темы';

  @override
  String get themeColorModeSingle => 'Один цвет темы';

  @override
  String get themeColorModeColorful => 'Разноцветная';

  @override
  String get themeColorUiColors => 'Цвета интерфейса';

  @override
  String get themeColorCourseColors => 'Цвета занятий';

  @override
  String get themeColorPrimary => 'Основной';

  @override
  String get themeColorSecondary => 'Дополнительный';

  @override
  String get themeColorTertiary => 'Третичный';

  @override
  String get themeColorCourseText => 'Текст занятия';

  @override
  String get themeColorCourseTextAuto => 'Авто';

  @override
  String get themeColorCourseTextCustom => 'Пользовательский цвет';

  @override
  String get themeColorCourseColorsEmpty =>
      'Цвета занятий будут сгенерированы после импорта расписания.';

  @override
  String get themeCustomColor => 'Пользовательский цвет';

  @override
  String get themeApplyCustomColor => 'Применить цвет';

  @override
  String get themeApplySettings => 'Применить настройки';

  @override
  String get dataImportExport => 'Импорт и экспорт данных';

  @override
  String get dataImportExportDesc =>
      'Импортируйте все данные или отдельные расписания, либо экспортируйте текущее/все расписания.';

  @override
  String get appBackupTitle =>
      'Резервное копирование и восстановление приложения';

  @override
  String get appBackupSubtitle =>
      'Создавайте резервные копии или восстанавливайте расписания, графики, настройки и сайты школ. API-ключи не включаются.';

  @override
  String get appBackupSheetSubtitle =>
      'Полное восстановление заменяет текущие данные приложения. Ключи AI API хранятся в защищенном хранилище и не записываются в файлы резервных копий.';

  @override
  String get restoreBackupFileTitle => 'Восстановить из JSON-файла';

  @override
  String get restoreBackupFileSubtitle =>
      'Выберите полный файл резервной копии Sked. Перед восстановлением потребуется подтверждение.';

  @override
  String get restoreBackupTextTitle => 'Вставить JSON резервной копии';

  @override
  String get restoreBackupTextSubtitle =>
      'Вставьте полную резервную копию и восстановите текущие данные приложения.';

  @override
  String get shareBackupTitle => 'Поделиться файлом резервной копии';

  @override
  String get shareBackupSubtitle =>
      'Экспортируйте все данные приложения в JSON. API-ключи исключаются.';

  @override
  String get saveBackupTitle => 'Сохранить файл резервной копии';

  @override
  String get saveBackupSubtitle =>
      'Сохраните полную резервную копию приложения в локальный файл.';

  @override
  String get copyBackupTitle => 'Копировать текст резервной копии';

  @override
  String get copyBackupSubtitle =>
      'Показать полный JSON резервной копии, чтобы его можно было скопировать или временно сохранить.';

  @override
  String get restoreBackupConfirmTitle =>
      'Восстановить полную резервную копию?';

  @override
  String get restoreBackupConfirmMessage =>
      'Это заменит все текущие расписания, общие графики, настройки и сайты школ. API-ключи не импортируются из резервных копий; введите ключ заново перед повторным разбором расписаний.';

  @override
  String get restoreBackupConfirmAction => 'Восстановить резервную копию';

  @override
  String get restoreBackupSuccessMessage =>
      'Полная резервная копия приложения восстановлена. Ключи AI API нужно ввести заново.';

  @override
  String get restoreBackupFailureMessage =>
      'Не удалось восстановить. Проверьте содержимое резервной копии и повторите попытку.';

  @override
  String get openSourceLicenses => 'Лицензии open source';

  @override
  String get openSourceLicensesDesc =>
      'Просмотр лицензий зависимостей Flutter и включённых ресурсов иконки приложения.';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Уже установлена последняя версия ($version)';
  }

  @override
  String get currentVersionLabel => 'Текущая версия';

  @override
  String get newVersionAvailable => 'Доступно обновление';

  @override
  String get latestVersionLabel => 'Последняя версия';

  @override
  String get updateContentLabel => 'Подробности обновления';

  @override
  String get officialWebsite => 'Официальный сайт';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Облачный диск';

  @override
  String get ignoreThisVersion => 'Игнорировать эту версию';

  @override
  String get openUpdatesFailed => 'Не удалось открыть ссылку на обновление';

  @override
  String get updateCheckFailedTitle => 'Не удалось проверить обновления';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Репозиторий GitHub';

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
      'Не удалось открыть ссылку на репозиторий GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Не удалось открыть ссылку на политику конфиденциальности';

  @override
  String get selectPeriodTimeSet => 'Выберите набор времени пар';

  @override
  String get newItem => 'Новый';

  @override
  String get editPeriodTimeSet => 'Редактировать набор времени пар';

  @override
  String get importTimetableFiles => 'Импортировать расписание';

  @override
  String get importTimetableFilesDesc =>
      'Поддерживается один или несколько файлов расписания.';

  @override
  String get importTimetableText => 'Импортировать расписание из текста';

  @override
  String get importTimetableTextDesc =>
      'Вставьте JSON-содержимое расписания и импортируйте его.';

  @override
  String get shareTimetableFiles => 'Поделиться файлами расписания';

  @override
  String get shareTimetableFilesDesc =>
      'Сначала выберите одно или несколько расписаний.';

  @override
  String get saveTimetableFiles => 'Сохранить файлы расписания';

  @override
  String get saveTimetableFilesDesc =>
      'Сначала выберите одно или несколько расписаний.';

  @override
  String get exportTimetableText => 'Экспортировать расписание как текст';

  @override
  String get exportTimetableTextDesc =>
      'Выберите одно или несколько расписаний, затем скопируйте JSON-содержимое.';

  @override
  String get jsonContent => 'JSON-содержимое';

  @override
  String get pasteJsonContentHint => 'Вставьте JSON-содержимое для импорта.';

  @override
  String get jsonContentEmpty => 'Сначала вставьте JSON-содержимое.';

  @override
  String get copyText => 'Копировать';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get share => 'Поделиться';

  @override
  String get selectTimetablesToExport => 'Выберите расписания для экспорта';

  @override
  String get selectTimetablesToImport => 'Выберите расписания для импорта';

  @override
  String timetableCourseCount(int count) {
    return '$count занятий';
  }

  @override
  String get importAction => 'Импортировать';

  @override
  String get importTimetableDialogTitle => 'Импорт расписания';

  @override
  String get chooseImportMethod => 'Выберите способ импорта.';

  @override
  String get importAsNewTimetable => 'Импортировать как новое расписание';

  @override
  String get replaceCurrentTimetable => 'Заменить текущее расписание';

  @override
  String get importPeriodTimeSetDialogTitle => 'Импорт наборов времени пар';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Этот файл содержит встроенные наборы времени пар. Хотите импортировать их и связать с расписанием?';

  @override
  String get importBundledPeriodTimeSets => 'Импортировать и связать';

  @override
  String get discardBundledPeriodTimeSets => 'Отбросить встроенные наборы';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Нет доступного существующего набора времени пар, поэтому встроенные наборы нельзя отбросить.';

  @override
  String savedToPath(Object path) {
    return 'Сохранено в $path';
  }

  @override
  String get saveCancelled => 'Сохранение отменено';

  @override
  String get fileSaveRestrictedTitle => 'Сохранение файла ограничено';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Система не смогла сохранить файл. Вы можете попробовать снова или использовать общий доступ.';

  @override
  String get retrySave => 'Повторить сохранение';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Включите доступ к файлам в настройках системы, затем вернитесь и попробуйте экспортировать снова.';

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String get browserDownloadRestrictedTitle => 'Загрузка в браузере ограничена';

  @override
  String get browserDownloadRestrictedMessage =>
      'Этот браузер не поддерживает прямое сохранение в локальный файл. Проверьте разрешения на загрузку или используйте общий доступ к файлу.';

  @override
  String get switchToShare => 'Использовать общий доступ';

  @override
  String get fileSaveFailedTitle => 'Не удалось сохранить файл';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Не удалось записать в текущий путь. Целевая папка может быть защищена, файл может использоваться или путь может быть недоступен для записи.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Система не смогла сохранить файл. Вы можете повторить попытку, проверить настройки системы или использовать общий доступ к файлу.';

  @override
  String get retryLater => 'Попробовать позже';

  @override
  String get exportSwitchedToShare =>
      'Для экспорта включён общий доступ к файлу';

  @override
  String get saveFailedRetry =>
      'Не удалось сохранить. Пожалуйста, попробуйте позже.';

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
  String get appInstanceBlockedTitle => 'Sked уже открыт';

  @override
  String get appInstanceBlockedMessage =>
      'Локальные данные используются в другом окне Sked или вкладке браузера. Закройте другое окно или вкладку и повторите попытку.';

  @override
  String get appInstanceLeaseFailedTitle => 'Локальные данные недоступны';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked не удалось подтвердить монопольный доступ к локальным данным. Данные не были открыты или изменены. Проверьте доступ к хранилищу и повторите попытку.';

  @override
  String get savingChanges => 'Сохранение изменений...';

  @override
  String get showApiKey => 'Показать API-ключ';

  @override
  String get hideApiKey => 'Скрыть API-ключ';

  @override
  String get importFailedCheckContent =>
      'Импорт не удался. Проверьте содержимое файла.';

  @override
  String get noImportableTimetables =>
      'В импортированном файле не найдено пригодных расписаний.';

  @override
  String importedTimetablesCount(int count) {
    return 'Импортировано расписаний: $count';
  }

  @override
  String get periodTimesTitle => 'Время пар';

  @override
  String get importExport => 'Импорт и экспорт';

  @override
  String get importPeriodTemplate => 'Импортировать шаблон пар';

  @override
  String get importPeriodTemplateText => 'Импортировать шаблон пар из текста';

  @override
  String get sharePeriodTemplate => 'Поделиться шаблоном пар';

  @override
  String get saveTemplateToFile => 'Сохранить шаблон в файл';

  @override
  String get exportPeriodTemplateText => 'Экспортировать шаблон пар как текст';

  @override
  String get deletePeriodTimeSet => 'Удалить набор времени пар';

  @override
  String get periodTimeSetName => 'Название набора времени пар';

  @override
  String get addOnePeriod => 'Добавить пару';

  @override
  String periodNumberLabel(int index) {
    return 'Пара $index';
  }

  @override
  String get deleteThisPeriod => 'Удалить эту пару';

  @override
  String durationMinutes(int minutes) {
    return 'Длительность $minutes мин';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Перерыв от предыдущей $minutes мин';
  }

  @override
  String get endTimeMustBeLater =>
      'Время окончания должно быть позже времени начала';

  @override
  String get periodOverlapPrevious => 'Эта пара пересекается с предыдущей';

  @override
  String get periodTimesSaved => 'Время пар сохранено';

  @override
  String get deletePeriodTimeSetTitle => 'Удалить набор времени пар';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Удалить \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'текущий набор времени пар';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Импортировано времён пар: $count';
  }

  @override
  String get periodFilePermissionTitle =>
      'Требуется разрешение на доступ к файлам';

  @override
  String get androidFilePermissionMessage =>
      'Для экспорта на Android требуется разрешение на доступ к файлам. Предоставьте его, чтобы продолжить сохранение.';

  @override
  String get reauthorize => 'Авторизовать снова';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Разрешение окончательно отклонено';

  @override
  String get permissionSettingsExportMessage =>
      'Включите доступ к файлам в настройках системы, затем вернитесь и попробуйте экспортировать снова.';

  @override
  String get privacyPolicyTitle => 'Политика конфиденциальности';

  @override
  String get privacyPolicyEntryDesc =>
      'Узнайте, как приложение обрабатывает локальное хранилище, конфигурацию школьных сайтов, импорт/экспорт файлов, разбор веб-страниц и внешние ссылки.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Принятая версия: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked — это локально-ориентированный инструмент для расписаний. Расписания, наборы времени пар и конфигурация школьных сайтов хранятся только на вашем устройстве или в браузере и никогда не загружаются автоматически. Приложение обрабатывает данные только тогда, когда вы явно запускаете такие действия, как импорт, разбор веб-страниц, общий доступ или открытие внешних ссылок. Полная политика конфиденциальности доступна онлайн.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Локальное хранилище';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Импорт и экспорт';

  @override
  String get privacyPolicyImportExportBody =>
      'Приложение читает или записывает JSON-файлы расписаний, JSON-файлы школьных сайтов и файлы шаблонов пар только тогда, когда вы явно выбираете файл или запускаете экспорт. Импорт этих файлов выполняется локально, если только вы дополнительно не выбираете разбор веб-страницы. Получение списка пользовательских моделей также является явным сетевым действием и обращается только к настроенной вами конечной точке.';

  @override
  String get privacyPolicySharingTitle => 'Общий доступ';

  @override
  String get privacyPolicySharingBody =>
      'Когда вы явно используете общий доступ, приложение передаёт экспортированный файл в системное меню общего доступа или в выбранное вами приложение. Дальнейшая обработка этого файла зависит от выбранного приложения или сервиса.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Внешние ссылки';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Когда вы открываете внешние ссылки, например репозиторий GitHub, приложение передаёт действие вашему браузеру или другому внешнему приложению. Обработка данных после этого регулируется третьей стороной, которую вы открываете.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Что приложение не собирает';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Приложению не требуется учётная запись Sked, и в нём не используются аналитика, рекламные идентификаторы или облачное резервное копирование. Также в нём нет отдельного поля для сбора паролей от школьных учётных записей. Если вы входите на школьный сайт внутри приложения, это взаимодействие происходит на открытой вами школьной странице.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Разбор веб-страниц';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Когда вы используете импорт школьной веб-страницы или анализируете вставленный текст расписания / HTML, приложение сначала подготавливает и очищает содержимое локально, а затем отправляет отправленный текст расписания, текст страницы или HTML-содержимое, необязательные заголовок и URL страницы, текущий язык приложения и содержимое prompt для парсера в настроенный вами OpenAI-совместимый endpoint. Получение списка моделей также обращается к этому же endpoint. Sked не предоставляет встроенный endpoint парсера и не отправляет запросы анализа на управляемый разработчиком backend парсера расписаний. Пользовательский endpoint и любые вышестоящие сервисы могут сохранять, пересылать, ограничивать, удалять или иным образом обрабатывать данные согласно правилам выбранного вами поставщика услуг. Если вы используете http:// Base URL, делайте это только на доверенных устройствах, в доверенных сетях и с доверенными endpoint-сервисами, поскольку содержимое и API-ключи могут не быть защищены транспортным шифрованием.';

  @override
  String get privacyPolicyUpdatesTitle => 'Обновления политики';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Текущая версия политики конфиденциальности — $version. Если в более поздней версии изменится способ обработки данных, приложение может попросить вас снова прочитать и принять обновлённую политику.';
  }

  @override
  String get privacyGateTitle =>
      'Пожалуйста, согласитесь с политикой конфиденциальности перед использованием приложения';

  @override
  String get privacyGateSummaryStorage =>
      'Расписания, наборы времени пар и конфигурация школьных сайтов хранятся только локально и не загружаются автоматически на сервер разработчика.';

  @override
  String get privacyGateSummaryImportExport =>
      'Импорт, экспорт и общий доступ происходят только когда вы явно их запускаете; разбор веб-страниц отправляет только сжатое содержимое, которое вы предоставили, на настроенную вами конечную точку разбора, а перед сохранением вы можете просмотреть распознанное расписание.';

  @override
  String get privacyGateSummaryUpdates =>
      'Если в более поздней версии изменится способ обработки данных, приложение может попросить вас снова ознакомиться с обновлённой политикой конфиденциальности.';

  @override
  String get schoolWebImportEntry => 'Импорт с веб-страницы школы';

  @override
  String get schoolWebImportEntryDesc =>
      'Импортировать текущую страницу расписания с сайта учебного заведения.';

  @override
  String get schoolSitesManageEntry => 'Управление школьными сайтами';

  @override
  String get schoolSitesManageEntryDesc =>
      'Добавление, редактирование и удаление URL-адресов входа, а также импорт и экспорт JSON.';

  @override
  String get schoolSitesPageTitle => 'Управление школьными сайтами';

  @override
  String get schoolSitesImportJson => 'Импортировать школьный JSON';

  @override
  String get schoolSitesShareJson => 'Поделиться школьным JSON';

  @override
  String get schoolSitesSaveJson => 'Сохранить школьный JSON';

  @override
  String get schoolSitesSaved => 'Школьные сайты сохранены';

  @override
  String get schoolSitesImported => 'Школьные сайты импортированы';

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
      'Конфигурация школьных сайтов пока отсутствует.';

  @override
  String get schoolSitesNameLabel => 'Название учебного заведения';

  @override
  String get schoolSitesLoginUrlLabel => 'URL входа';

  @override
  String get schoolSitesAdd => 'Добавить учебное заведение';

  @override
  String get schoolSitesEdit => 'Редактировать учебное заведение';

  @override
  String get schoolSitesDeleteTitle => 'Удалить учебное заведение';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Удалить \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Сначала заполните название учебного заведения и URL входа.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Импорт вставкой содержимого страницы расписания';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Вставьте исходный код или необработанное содержимое страницы с информацией о расписании вручную.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Разобрать расписание из содержимого страницы';

  @override
  String get schoolHtmlImportUrlLabel => 'URL-источник (необязательно)';

  @override
  String get schoolHtmlImportTitleLabel => 'Заголовок страницы (необязательно)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Содержимое страницы';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Вставьте сюда исходный код или необработанное содержимое страницы с информацией о расписании.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Можно разобрать и импортировать любой контент, содержащий информацию о расписании, не только HTML.';

  @override
  String get schoolHtmlImportCompress => 'Подготовить содержимое';

  @override
  String get schoolHtmlImportCompressed => 'Содержимое подготовлено';

  @override
  String get schoolHtmlImportCompressFirst => 'Сначала подготовьте содержимое.';

  @override
  String get schoolHtmlImportSubmit => 'Разобрать и импортировать';

  @override
  String get schoolImportContentTruncated =>
      'Эта страница достигла безопасного ограничения на импорт. На анализ будет отправлена только сохранённая часть.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Разбор может занять некоторое время. Пожалуйста, подождите.';

  @override
  String get schoolHtmlImportEmpty => 'Сначала вставьте HTML-код страницы.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Назад к веб-странице';

  @override
  String get schoolWebImportPageTitle => 'Импорт с веб-страницы школы';

  @override
  String get schoolWebImportPreview => 'Предпросмотр импорта';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count занятий';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count пар';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Заголовок страницы';

  @override
  String get schoolWebImportParserUsed => 'Парсер';

  @override
  String get schoolWebImportWarnings => 'Примечания к импорту';

  @override
  String get schoolWebImportOpenPageHint =>
      'Войдите на школьный сайт внутри приложения, затем вручную перейдите на страницу расписания.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Эта платформа пока не поддерживает встроенный вход через веб-интерфейс. Пожалуйста, используйте платформу с поддержкой WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Выберите учебное заведение';

  @override
  String get schoolWebImportNoSchools =>
      'Конфигурация учебных заведений недоступна. Сначала проверьте school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Не удалось загрузить конфигурацию учебных заведений. Проверьте формат JSON-файла.';

  @override
  String get schoolWebImportImportCurrentPage =>
      'Импортировать текущую страницу';

  @override
  String get schoolWebImportGoBack => 'Предыдущая страница';

  @override
  String get schoolWebImportLoadingPage => 'Загрузка страницы…';

  @override
  String get schoolWebImportParsing => 'Разбор текущей страницы…';

  @override
  String get schoolWebImportLoadFailed =>
      'Не удалось загрузить страницу. Пожалуйста, обновите её или попробуйте позже.';

  @override
  String get schoolWebImportLoadTimedOut =>
      'Время загрузки страницы истекло. Обновите страницу и попробуйте снова.';

  @override
  String get schoolWebImportUnknownOrigin => 'Неизвестный сайт';

  @override
  String get schoolWebImportCrossOriginTitle => 'Перейти на другой сайт?';

  @override
  String schoolWebImportCrossOriginMessage(Object origin) {
    return 'Для входа в школьную систему может потребоваться открыть другой сайт. Продолжайте, только если доверяете этому адресу в рамках текущего сеанса импорта:\n\n$origin';
  }

  @override
  String get schoolWebImportEmptyPage =>
      'Содержимое текущей страницы пусто и пока не может быть импортировано.';

  @override
  String get schoolWebImportSuccess => 'Веб-расписание импортировано';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSettingsLocationHint =>
      'Configure it in Settings > Data & security > AI API configuration.';

  @override
  String get schoolImportParserSourceTitle => 'Источник парсера';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Пользовательский OpenAI-совместимый';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Пользовательский OpenAI-совместимый парсер';

  @override
  String get schoolImportParserCustomPromptTitle =>
      'Пользовательская подсказка';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Здесь можно редактировать встроенную подсказку парсера. Изменения влияют только на пользовательский OpenAI-совместимый парсер.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'По умолчанию здесь загружается встроенная подсказка. Очистите её, чтобы вернуться к встроенной версии.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Сбросить подсказку по умолчанию';

  @override
  String get schoolImportParserBaseUrl => 'Base URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL должен быть HTTP- или HTTPS-адресом с хостом.';

  @override
  String get schoolImportParserApiKey => 'API key';

  @override
  String get schoolImportParserModel => 'Модель';

  @override
  String get schoolImportParserFetchModels => 'Получить список моделей';

  @override
  String get schoolImportParserFetchingModels => 'Получение списка моделей...';

  @override
  String get schoolImportParserNoModelsFound =>
      'Конечная точка не вернула ни одной модели.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Не удалось получить модели. Проверьте конечную точку и повторите попытку.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Получено моделей: $count';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Использовать незашифрованный HTTP-адрес?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'Ключ API и содержимое расписания могут быть прочитаны или изменены при передаче. Продолжайте, только если доверяете этому устройству, сети и адресу. Разрешение действует до закрытия Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Конфигурация пользовательского парсера неполная. Сначала заполните Base URL, API key и модель.';

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
    return 'Парсер: пользовательский ($model)';
  }

  @override
  String get privacyViewFullPolicy =>
      'Просмотреть полную политику конфиденциальности';

  @override
  String get privacyAgreeAndContinue => 'Согласиться и продолжить';

  @override
  String get privacyDecline => 'Отклонить';

  @override
  String get privacyDeclineWebHint =>
      'В этой браузерной среде приложение не может закрыть страницу за вас. Если вы не согласны, пожалуйста, закройте эту вкладку или окно самостоятельно.';

  @override
  String get defaultPeriodTimeSetName => 'Пары по умолчанию';

  @override
  String get periodTimeSetFallbackName => 'Время пар';

  @override
  String get untitledTimetableName => 'Расписание без названия';

  @override
  String get newTimetableName => 'Новое расписание';

  @override
  String get newPeriodTimeSetName => 'Новый набор времени пар';

  @override
  String get emptyTimetableName => 'Пустое расписание';

  @override
  String importedPeriodTimeSetName(Object name) {
    return 'Пары $name';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Тип импортируемого файла не совпадает.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Эта версия импортируемого файла пока не поддерживается.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Во входном файле не найдено времени пар.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Пожалуйста, выберите хотя бы одно расписание.';

  @override
  String get noExportableTimetableMessage =>
      'Нет доступных для экспорта расписаний.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Замена текущего расписания поддерживает выбор только одного расписания.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Нет текущего расписания для замены.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Этот набор времени пар всё ещё используется в $count расписании(ях). Перед удалением переназначьте их.';
  }

  @override
  String get weekdayMonday => 'Понедельник';

  @override
  String get weekdayTuesday => 'Вторник';

  @override
  String get weekdayWednesday => 'Среда';

  @override
  String get weekdayThursday => 'Четверг';

  @override
  String get weekdayFriday => 'Пятница';

  @override
  String get weekdaySaturday => 'Суббота';

  @override
  String get weekdaySunday => 'Воскресенье';

  @override
  String get weekdayShortMonday => 'Пн';

  @override
  String get weekdayShortTuesday => 'Вт';

  @override
  String get weekdayShortWednesday => 'Ср';

  @override
  String get weekdayShortThursday => 'Чт';

  @override
  String get weekdayShortFriday => 'Пт';

  @override
  String get weekdayShortSaturday => 'Сб';

  @override
  String get weekdayShortSunday => 'Вс';

  @override
  String get monthJanuary => 'янв.';

  @override
  String get monthFebruary => 'февр.';

  @override
  String get monthMarch => 'мар.';

  @override
  String get monthApril => 'апр.';

  @override
  String get monthMay => 'май';

  @override
  String get monthJune => 'июн.';

  @override
  String get monthJuly => 'июл.';

  @override
  String get monthAugust => 'авг.';

  @override
  String get monthSeptember => 'сент.';

  @override
  String get monthOctober => 'окт.';

  @override
  String get monthNovember => 'нояб.';

  @override
  String get monthDecember => 'дек.';

  @override
  String get semesterWeeksWholeTerm => 'Весь семестр';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Недели $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Недели $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Выберите начальный режим';

  @override
  String get firstLaunchSubtitle =>
      'Выберите рабочую область, которой пользуетесь чаще всего. Режим можно изменить позже.';

  @override
  String get firstLaunchStudentDesc =>
      'Управляйте расписаниями, курсами, неделями, временем занятий и импортом.';

  @override
  String get firstLaunchGeneralDesc =>
      'Управляйте категориями, событиями, напоминаниями и данными JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Начать с расписания';

  @override
  String get firstLaunchStartGeneral => 'Начать с графика';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Выбирая начальное рабочее пространство, вы подтверждаете, что прочитали и принимаете ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Политику конфиденциальности';

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
  String get today => 'Сегодня';

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
      'Режимы просмотра, панель инструментов, формат даты и быстрое добавление';

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
  String get viewWeek => 'Неделя';

  @override
  String get viewDay => 'День';

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
  String get schoolWebImportSignInConsentTitle =>
      'Открыть вход в школьную систему?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'При входе в школьную систему учётные данные могут отправляться через формы или серверные перенаправления школе и её поставщикам входа. Android не может приостанавливать каждую такую передачу для отдельного подтверждения адреса. Продолжайте, только если доверяете им в рамках этого сеанса импорта:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Открыть небезопасный вход в школьную систему?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Этот вход в школьную систему использует HTTP. Любой, кто может просматривать или изменять это соединение, может прочитать либо изменить ваши учётные данные и содержимое страницы. Продолжайте, только если принимаете этот риск для:\n\n$origin';
  }

  @override
  String get developerModeTitle => 'Режим разработчика';

  @override
  String get developerModeDescription =>
      'Инструменты для добавления полного набора примеров для проверки интерфейса и взаимодействия.';

  @override
  String get developerSampleLanguage => 'Язык примеров';

  @override
  String get developerSampleChinese => 'Китайский';

  @override
  String get developerSampleEnglish => 'Английский';

  @override
  String get developerSampleDataDescription =>
      'Добавляет одно расписание, категории и события, не заменяя существующие данные.';

  @override
  String get developerAddSampleData => 'Добавить примеры';

  @override
  String get developerSampleDataAdded =>
      'Пример расписания и событий добавлен.';

  @override
  String get developerModeLongPressHint =>
      'Удерживайте 3 секунды, чтобы открыть режим разработчика';

  @override
  String get collapseWorkspaceNavigation =>
      'Свернуть навигацию рабочего пространства';

  @override
  String get expandWorkspaceNavigation =>
      'Развернуть навигацию рабочего пространства';
}
