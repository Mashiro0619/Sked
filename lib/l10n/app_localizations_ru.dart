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
  String get schoolImportResultEditorTitle => 'Редактировать результат разбора';

  @override
  String get schoolImportParsePageTitle => 'Разобрать расписание';

  @override
  String get schoolImportParsePageParsing => 'Идёт разбор…';

  @override
  String get schoolImportParsePageFailed => 'Ошибка разбора';

  @override
  String get schoolImportParsePageComplete => 'Разбор завершён';

  @override
  String get schoolImportParsePageContinue => 'Продолжить';

  @override
  String get schoolImportParsePageRawContent => 'Исходный ответ';

  @override
  String get schoolImportParsePageExpandRaw => 'Развернуть исходный ответ';

  @override
  String get schoolImportParsePageCollapseRaw => 'Свернуть исходный ответ';

  @override
  String get schoolImportExpandWarnings => 'Развернуть предупреждения импорта';

  @override
  String get schoolImportCollapseWarnings => 'Свернуть предупреждения импорта';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Некоторые предметы продолжаются до $week-й недели.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Заменить текущее расписание?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Импортированное расписание заменит текущее.';

  @override
  String get createTimetable => 'Новое расписание';

  @override
  String get jumpToWeek => 'Перейти к неделе';

  @override
  String get timetable => 'Расписание';

  @override
  String get themeWorkspaceSchedule => 'Календарь';

  @override
  String get timetableName => 'Название расписания';

  @override
  String get timetableNameRequired => 'Укажите название расписания';

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
  String get customFieldsInvalidJson =>
      'Введите корректный объект JSON или очистите поле.';

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
  String get settingsSectionTimetable => 'Расписание';

  @override
  String get settingsSectionGeneralSchedule => 'Календарь';

  @override
  String get settingsSectionAppearance => 'Оформление';

  @override
  String get settingsSectionApp => 'Приложение';

  @override
  String get settingsSectionWorkspace => 'Рабочая область';

  @override
  String get settingsSectionAppearanceLanguage => 'Оформление и язык';

  @override
  String get settingsSectionDataSecurity => 'Данные и безопасность';

  @override
  String get settingsSectionAbout => 'О Sked';

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
      'Горизонтальная компоновка и жесты';

  @override
  String get fitDaySelectorToWidth => 'Вместить выбор дня на экране';

  @override
  String get fitDaySelectorToWidthHint =>
      'По возможности показывает все семь дней на экране. Отключите для фиксированной ширины и прокрутки.';

  @override
  String get fitWeekColumnsToWidth => 'Вместить столбцы недели на экране';

  @override
  String get fitWeekColumnsToWidthHint =>
      'По возможности показывает все семь столбцов расписания на экране. Отключите для фиксированной ширины и прокрутки.';

  @override
  String get enableWeekSwipeNavigation => 'Переключать недели смахиванием';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Смахните влево или вправо для перехода к другой неделе. При фиксированной ширине сначала протяните содержимое за край.';

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
  String get microsoftStoreUpdates => 'Обновлениями управляет Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Получать предварительные версии';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Включать версии Alpha, Beta и RC, которые могут быть нестабильными. Если выключено, предлагаются только стабильные версии.';

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
      'Не удалось получить последнюю версию с GitHub. Вы можете открыть GitHub Releases ниже.';

  @override
  String get githubRepository => 'Репозиторий GitHub';

  @override
  String get googlePlayStoreDesc => 'Посмотреть Sked в Google Play';

  @override
  String get openGooglePlayFailed => 'Не удалось открыть Google Play';

  @override
  String get starSkedOnGithub => 'Поставьте Sked звезду на GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Откройте репозиторий проекта и поставьте Sked звезду';

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
  String get periodTimesUnsavedExitTitle => 'Изменения не сохранены';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Не удалось сохранить последние изменения времени занятий. Повторите попытку, продолжите редактирование или отмените изменения.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Некоторые интервалы занятий некорректны. Исправьте их перед сохранением или отмените изменения и выйдите.';

  @override
  String get discardChangesAndExit => 'Отменить изменения и выйти';

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
      'На нативных платформах Sked хранит расписания занятий, календари, связанные настройки и редактируемую конфигурацию сайтов учебных заведений в системном каталоге данных приложения; браузерные версии используют хранилище браузера. Файлы, записанные предыдущими версиями в папку «Документы» пользователя, остаются на месте, но не читаются и не переносятся автоматически. Чтобы сохранить эти данные, перед обновлением экспортируйте полную резервную копию приложения из старой версии, а затем восстановите её. Настройки API ИИ хранятся локально; пользовательский API-ключ сохраняется в защищённом хранилище платформы, если оно доступно. Полные резервные копии приложения не содержат пользовательский API-ключ. Приложение не загружает эти локальные данные автоматически на сервер, управляемый разработчиком.';

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
  String get schoolSitesImportPreviewTitle =>
      'Проверка импорта сайтов учебных заведений';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return 'Допустимых сайтов: $validCount, некорректных записей: $invalidCount.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Файл содержит пустой список сайтов учебных заведений.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Запись $position некорректна и будет пропущена.';
  }

  @override
  String get schoolSitesImportMerge => 'Объединить';

  @override
  String get schoolSitesImportReplace => 'Заменить';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Заменить текущие сайты учебных заведений?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Будут удалены текущие сайты ($currentCount) и сохранены импортированные ($importedCount). Это действие нельзя отменить.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Данные сайтов учебных заведений требуют восстановления';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked не удалось прочитать файл сайтов учебных заведений или его резервную копию. Перед блокировкой записи были созданы защищённые копии.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Хранилище сайтов учебных заведений недоступно';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Сейчас Sked не может получить доступ к хранилищу сайтов учебных заведений. Проверьте доступ к хранилищу и доступность устройства, затем повторите попытку. Текущие данные сайтов не будут перезаписаны.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Ниже перечислены файлы восстановления или затронутые расположения хранилища. Не изменяйте файлы до восстановления списка сайтов.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Начать без сайтов учебных заведений';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Начать с пустого списка сайтов учебных заведений?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Защищённые копии сохранятся, но Sked создаст новый пустой файл сайтов учебных заведений. Продолжайте, только если не хотите сначала повторить восстановление.';

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
  String get schoolWebImportParserDetails => 'Сведения об анализе';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Развернуть сведения об анализе';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Свернуть сведения об анализе';

  @override
  String get schoolWebImportOpenPageHint =>
      'Войдите на школьный сайт внутри приложения, затем вручную перейдите на страницу расписания.';

  @override
  String get schoolWebImportConfigMissing =>
      'Настройка пользовательского парсера не завершена. Сначала укажите базовый URL, API-ключ и модель.';

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
  String get schoolWebImportLoadingPage => 'Загрузка страницы…';

  @override
  String get schoolWebImportParsing => 'Разбор текущей страницы…';

  @override
  String get schoolWebImportLoadFailed =>
      'Не удалось загрузить страницу. Пожалуйста, обновите её или попробуйте позже.';

  @override
  String get schoolWebImportUnknownOrigin => 'Неизвестный сайт';

  @override
  String get schoolWebImportExitTitle => 'Выйти из браузера?';

  @override
  String get schoolWebImportExitMessage =>
      'Страница будет закрыта. Всё, что вы ещё не импортировали, будет потеряно.';

  @override
  String get schoolWebImportExitConfirm => 'Выйти';

  @override
  String get schoolWebImportEmptyPage =>
      'Содержимое текущей страницы пусто и пока не может быть импортировано.';

  @override
  String get schoolWebImportSuccess => 'Веб-расписание импортировано';

  @override
  String get schoolImportParserSettingsTitle => 'API разбора расписания';

  @override
  String get schoolImportParserSettingsDesc =>
      'Настройте совместимый с OpenAI API для импорта расписаний. Это не настройки чат-помощника.';

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
  String get schoolImportParserBaseUrl => 'Базовый URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL должен быть HTTP- или HTTPS-адресом с хостом.';

  @override
  String get schoolImportParserApiKey => 'API-ключ';

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
      'Пользовательский API-ключ сохраняется в защищённом хранилище платформы, если оно доступно. Используйте учётные данные пользовательского парсера и HTTP-адреса только на доверенных устройствах, в доверенных браузерах и сетях.';

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
  String get clearAppData => 'Очистить данные';

  @override
  String get clearAppDataDesc =>
      'Удалить все локальные данные Sked без возможности восстановления и выйти из приложения';

  @override
  String get clearAppDataConfirmTitle => 'Очистить все данные Sked?';

  @override
  String get clearAppDataConfirmMessage =>
      'Будут безвозвратно удалены расписания, календари, настройки, сайты учебных заведений, локальные резервные копии, копии восстановления и API-ключ ИИ, после чего Sked закроется. Файлы, экспортированные в другие места, не будут удалены. Это действие нельзя отменить.';

  @override
  String get clearAppDataAction => 'Очистить данные и выйти';

  @override
  String get clearAppDataFailed =>
      'Не удалось очистить все локальные данные. Sked останется открытым, чтобы вы могли повторить попытку.';

  @override
  String get clearAppDataExitFailed =>
      'Локальные данные очищены, но Sked не удалось закрыть. Закройте приложение вручную перед дальнейшим использованием.';

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
  String get generalSchedule => 'Календарь';

  @override
  String get studentTimetable => 'Учебное расписание';

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
  String get switchMode => 'Переключить режим';

  @override
  String get generalScheduleComingSoon => 'Календарь скоро появится';

  @override
  String get switchToStudentTimetable => 'Перейти к учебному расписанию';

  @override
  String get mySchedule => 'Мой календарь';

  @override
  String get today => 'Сегодня';

  @override
  String get addEvent => 'Добавить событие';

  @override
  String get editEvent => 'Редактировать событие';

  @override
  String get eventTitle => 'Название';

  @override
  String get eventTitleRequired => 'Укажите название';

  @override
  String get eventStartTime => 'Время начала';

  @override
  String get eventEndTime => 'Время окончания';

  @override
  String get eventDate => 'Дата';

  @override
  String get eventTime => 'Время';

  @override
  String get eventNotes => 'Заметки';

  @override
  String get eventColor => 'Цвет';

  @override
  String get eventRecurrence => 'Повтор';

  @override
  String get recurrenceNone => 'Не повторяется';

  @override
  String get recurrenceWeekly => 'Еженедельно';

  @override
  String get recurrenceEndDate => 'Дата окончания';

  @override
  String get recurrenceNoEndDate => 'Без даты окончания';

  @override
  String get recurrenceSetEndDate => 'Установить';

  @override
  String get recurrenceChangeEndDate => 'Изменить';

  @override
  String get repeatsWeekly => 'Повторяется еженедельно';

  @override
  String recurrenceUntil(Object date) {
    return 'До $date';
  }

  @override
  String get switchToGeneralSchedule => 'Перейти к календарю';

  @override
  String get generalDisplaySettings => 'Общие настройки отображения';

  @override
  String get generalDisplaySettingsDesc =>
      'Режимы просмотра, панель инструментов, формат даты и быстрое добавление';

  @override
  String get closePopupOnOutsideTap => 'Закрывать окно по нажатию снаружи';

  @override
  String get showGridLines => 'Показывать линии сетки';

  @override
  String get generalScheduleImportExport => 'Импорт и экспорт категорий';

  @override
  String get generalScheduleImportExportDesc =>
      'Импортировать или отправить категории календаря';

  @override
  String get importGeneralSchedules => 'Импортировать категории';

  @override
  String get importGeneralSchedulesDesc => 'Загрузить категории из файла JSON';

  @override
  String get shareGeneralSchedules => 'Отправить категории';

  @override
  String get shareGeneralSchedulesDesc =>
      'Отправить категории в виде файла JSON';

  @override
  String get saveGeneralSchedules => 'Сохранить категории';

  @override
  String get saveGeneralSchedulesDesc => 'Сохранить категории в файл JSON';

  @override
  String get selectSchedulesToExport => 'Выберите категории для экспорта';

  @override
  String get selectSchedulesToImport => 'Выберите категории для импорта';

  @override
  String generalScheduleEventCount(int count) {
    return 'Событий: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Импортировано категорий: $count';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Добавить импорт как новую категорию или заменить существующую?';

  @override
  String get addAsNewSchedule => 'Добавить как новую категорию';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Выберите хотя бы одну категорию.';

  @override
  String get noExportableScheduleMessage => 'Нет категорий для экспорта.';

  @override
  String get noSchedulesInImportMessage =>
      'Файл импорта не содержит категорий.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Для замены выберите ровно одну импортированную категорию.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Выбранная для замены категория недоступна.';

  @override
  String get calendars => 'Категории';

  @override
  String get calendar => 'Категория';

  @override
  String get viewWeek => 'Неделя';

  @override
  String get viewDay => 'День';

  @override
  String get viewList => 'Список';

  @override
  String get viewMonth => 'Месяц';

  @override
  String visibleCategoryCount(int count) {
    return 'Категорий: $count';
  }

  @override
  String get noVisibleCategories => 'Нет видимых категорий';

  @override
  String get selectCategoryToReplace => 'Выберите категорию для замены';

  @override
  String get replaceCategory => 'Заменить категорию';

  @override
  String get deleteEventTitle => 'Удалить событие';

  @override
  String get deleteEventConfirmation =>
      'Это событие будет удалено без возможности восстановления.';

  @override
  String get deleteRecurringEventTitle => 'Удалить повторяющееся событие';

  @override
  String get eventDuplicated => 'Событие продублировано';

  @override
  String get searchEvents => 'Поиск событий';

  @override
  String get clearSearch => 'Очистить поиск';

  @override
  String get filterByColor => 'Фильтр по цвету';

  @override
  String get allColors => 'Все цвета';

  @override
  String upcomingEventsCount(int count) {
    return 'Предстоящих: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Просроченных: $count';
  }

  @override
  String get allDay => 'Весь день';

  @override
  String get collapseAllDayTimeline => 'Свернуть события на весь день';

  @override
  String get expandAllDayTimeline => 'Развернуть события на весь день';

  @override
  String allDayEventsCount(int count) {
    return 'Событий на весь день: $count';
  }

  @override
  String moreEvents(int count) {
    return 'Ещё $count';
  }

  @override
  String get noMatchingEvents => 'Нет подходящих событий';

  @override
  String get noUpcomingEvents => 'Нет предстоящих событий';

  @override
  String get addCalendar => 'Добавить категорию';

  @override
  String get newCalendar => 'Новая категория';

  @override
  String get hideCalendar => 'Скрыть категорию';

  @override
  String get showCalendar => 'Показать категорию';

  @override
  String get rename => 'Переименовать';

  @override
  String get renameCalendar => 'Переименовать категорию';

  @override
  String get name => 'Название';

  @override
  String get deleteCalendar => 'Удалить категорию';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteThisOccurrence => 'Удалить только это событие';

  @override
  String get deleteFutureOccurrences => 'Удалить это и последующие';

  @override
  String get deleteAllOccurrences => 'Удалить всю серию';

  @override
  String get duplicateEvent => 'Дублировать';

  @override
  String get repeatsDaily => 'Повторяется ежедневно';

  @override
  String get repeatsMonthly => 'Повторяется ежемесячно';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Интервал повтора: $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return 'Повторений: $count';
  }

  @override
  String get recurrenceDaily => 'Ежедневно';

  @override
  String get recurrenceMonthly => 'Ежемесячно';

  @override
  String get recurrenceCustom => 'Настроить';

  @override
  String get recurrenceEvery => 'Каждые';

  @override
  String get recurrenceUnit => 'Единица';

  @override
  String get recurrenceDays => 'дн.';

  @override
  String get recurrenceWeeks => 'нед.';

  @override
  String get recurrenceMonths => 'мес.';

  @override
  String get recurrenceRepeatCount => 'Количество повторений';

  @override
  String get recurrenceNoLimit => 'Без ограничений';

  @override
  String get recurrencePositiveNumber => 'Введите положительное число';

  @override
  String get clearEndDate => 'Очистить дату окончания';

  @override
  String get pickDate => 'Выбрать дату';

  @override
  String get pickTime => 'Выбрать время';

  @override
  String get reminder => 'Напоминание в приложении';

  @override
  String get reminderAtStart => 'В момент начала';

  @override
  String reminderMinutesBefore(int minutes) {
    return 'За $minutes мин';
  }

  @override
  String get reminderHourBefore => 'За 1 час';

  @override
  String get reminderDayBefore => 'За 1 день';

  @override
  String get markReminderHandled => 'Отметить обработанным';

  @override
  String get restoreReminder => 'Восстановить напоминание в приложении';

  @override
  String get reminderHandled =>
      'Напоминание в приложении отмечено обработанным';

  @override
  String get reminderRestored => 'Напоминание в приложении восстановлено';

  @override
  String get reminderUpcoming => 'Предстоит';

  @override
  String get reminderOverdue => 'Просрочено';

  @override
  String get generalFitWeekColumnsToWidth => 'Вместить неделю на экране';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Показывать всю неделю в компактном режиме. Отключите для горизонтальной прокрутки. Произвольные диапазоны свыше 7 дней по-прежнему прокручиваются.';

  @override
  String get showWeekends => 'Показывать выходные';

  @override
  String get startHour => 'Начальный час';

  @override
  String get endHour => 'Конечный час';

  @override
  String get timeGridDensity => 'Плотность сетки времени';

  @override
  String get timeGridHourHeight => 'Высота строки часа';

  @override
  String get timeGridHourHeightHint =>
      'Меняет вертикальный масштаб дневного и недельного видов, не изменяя шаг сетки в 15, 30 или 60 минут.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Импортировать файл JSON';

  @override
  String get pasteJson => 'Вставить JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Импортировать категории из скопированного JSON';

  @override
  String get importIcsFile => 'Импортировать файл ICS';

  @override
  String get importIcsFileDesc => 'Загрузить события из файла календаря .ics';

  @override
  String get pasteIcs => 'Вставить ICS';

  @override
  String get pasteIcsDesc =>
      'Импортировать события из скопированного текста календаря';

  @override
  String get copyJson => 'Копировать JSON';

  @override
  String get copyJsonDesc => 'Копировать выбранные категории как текст JSON';

  @override
  String get shareIcs => 'Отправить ICS';

  @override
  String get shareIcsDesc => 'Отправить выбранные календари в формате .ics';

  @override
  String get saveIcs => 'Сохранить ICS';

  @override
  String get saveIcsDesc => 'Сохранить выбранные календари в формате .ics';

  @override
  String get copyIcs => 'Копировать ICS';

  @override
  String get copyIcsDesc => 'Копировать выбранные календари как текст ICS';

  @override
  String get importIcs => 'Импортировать ICS';

  @override
  String get icsContent => 'Содержимое ICS';

  @override
  String get pasteIcsContentHint => 'Вставьте сюда содержимое BEGIN:VCALENDAR';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Найдено событий: $count. Добавить их в новую категорию или заменить существующую?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Импортировано категорий: $count; предупреждений: $warningCount';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Пропущено событие без времени начала.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Пропущено событие с неподдерживаемым временем начала.';

  @override
  String get importWarningAdjustedEnd =>
      'Исправлено время окончания события, которое не было позже времени начала.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Неподдерживаемые поля ICS добавлены в заметки: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Неподдерживаемая частота повторения проигнорирована: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Выберите календари для копирования в ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Выберите календари для экспорта в ICS';

  @override
  String get exportIcsText => 'Экспортировать текст ICS';

  @override
  String get exportJsonText => 'Экспортировать текст JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Данные приложения восстановлены из предыдущей резервной копии, поскольку основной файл не удалось загрузить.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Основной файл данных и его резервная копия повреждены. Приложение использует новое исходное состояние.';

  @override
  String get dataRecoveryCorruptTitle => 'Ваши данные требуют восстановления';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked не удалось прочитать основной файл данных или его резервную копию. Перед блокировкой записи были созданы защищённые копии.';

  @override
  String get dataRecoveryIoFailureTitle => 'Хранилище недоступно';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Сейчас Sked не может получить доступ к локальному хранилищу. Проверьте доступ к хранилищу и доступность устройства, затем повторите попытку. Существующие данные не будут перезаписаны.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Обновите Sked, чтобы открыть эти данные';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Эти данные созданы более новой версией Sked. Обновите приложение перед повторной попыткой. Начать заново нельзя, чтобы защитить данные.';

  @override
  String get dataRecoveryRetryAction => 'Повторить';

  @override
  String get dataRecoveryArtifactsHint =>
      'Ниже перечислены файлы восстановления или затронутые расположения хранилища. Не изменяйте файлы до восстановления данных.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Показать файлы и расположения восстановления';

  @override
  String get dataRecoveryStartFreshAction => 'Начать с новыми данными';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Начать с новыми данными?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Защищённые копии сохранятся, но Sked создаст новый локальный файл данных. Продолжайте, только если не хотите сначала повторить восстановление.';

  @override
  String get previousMonth => 'Предыдущий месяц';

  @override
  String get nextMonth => 'Следующий месяц';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get reminderInProgress => 'Идёт сейчас';

  @override
  String get deleteCourseTitle => 'Удалить предмет';

  @override
  String get deleteCourseMessage => 'Удалить этот предмет?';

  @override
  String get showLunarCalendar => 'Показывать лунный календарь';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, событий: $count';
  }

  @override
  String get defaultView => 'Вид по умолчанию';

  @override
  String get generalDefaultViewSection => 'При запуске';

  @override
  String get generalViewSwitchBehavior => 'Кнопка переключения вида';

  @override
  String get settingsWorkspaceMode => 'Активная рабочая область';

  @override
  String get hideHomeWorkspaceNavigation => 'Скрыть навигацию рабочих областей';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Скрыть навигацию по рабочим пространствам. Переключаться можно через меню на главном экране.';

  @override
  String get generalDateLabelFormat => 'Формат подписи даты';

  @override
  String get generalDateLabelFormatLocalized => 'Локальный (июл. 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Через косую черту (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Компоновка панели инструментов';

  @override
  String get toolbarNavigationSection => 'Навигация панели инструментов';

  @override
  String get toolbarNavigationHiddenBehavior => 'Скрытые элементы';

  @override
  String get toolbarNavigationRemove => 'Скрыть полностью';

  @override
  String get toolbarNavigationMore => 'Переместить в «Ещё»';

  @override
  String get toolbarNavigationReorder => 'Изменить порядок элементов панели';

  @override
  String get toolbarNavigationVisibility => 'Показывать элемент панели';

  @override
  String get toolbarNavigationTimetable => 'Выбор расписания';

  @override
  String get toolbarNavigationWeek => 'Выбор недели';

  @override
  String get toolbarNavigationView => 'Переключение вида';

  @override
  String get toolbarNavigationCategory => 'Выбор категории';

  @override
  String get toolbarNavigationDate => 'Выбор даты';

  @override
  String get generalToolbarWidthPolicy => 'Распределение места на панели';

  @override
  String get generalToolbarWidthContent => 'Автоматическое распределение';

  @override
  String get generalToolbarWidthBalanced => 'Сбалансированное';

  @override
  String get generalToolbarWidthCalendarPriority => 'Приоритет категории';

  @override
  String get generalToolbarWidthDatePriority => 'Приоритет даты';

  @override
  String get generalViewSwitchCycle => 'Переключать виды по кругу';

  @override
  String get generalViewSwitchMenu => 'Открывать меню видов';

  @override
  String get generalViewSwitchTooltip => 'Переключить вид';

  @override
  String get generalViewSwitchMenuTooltip => 'Выбрать вид';

  @override
  String get generalViewLongPressTodayHint =>
      'Удерживайте для перехода к сегодняшнему дню';

  @override
  String get generalScheduleDisplaySection => 'Отображение календаря';

  @override
  String get generalTimeGridSection => 'Сетка времени';

  @override
  String get generalPopupSection => 'Поведение всплывающего окна';

  @override
  String get quickActionsSection => 'Быстрые действия';

  @override
  String get showAddCourseFab =>
      'Показывать плавающую кнопку добавления предмета';

  @override
  String get showAddCourseFabHint =>
      'Показать или скрыть плавающую кнопку добавления предмета в правом нижнем углу расписания.';

  @override
  String get showAddEventFab =>
      'Показывать плавающую кнопку добавления события';

  @override
  String get showAddEventFabHint =>
      'Показать или скрыть плавающую кнопку добавления события в правом нижнем углу календаря.';

  @override
  String get enableLongPressAddCourse =>
      'Добавлять предметы удержанием пустой ячейки';

  @override
  String get enableLongPressAddCourseHint =>
      'Чтобы добавить предмет, нажмите и удерживайте пустую область сетки расписания.';

  @override
  String get enableLongPressAddEvent =>
      'Добавлять события удержанием пустой ячейки';

  @override
  String get enableLongPressAddEventHint =>
      'В дневном или недельном виде нажмите и удерживайте пустую область сетки времени, чтобы добавить событие.';

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
  String get developerNotificationDiagnostics => 'Диагностика уведомлений';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Проверьте состояние доставки в Android, перестройте существующий план напоминаний и отправьте безопасные тестовые уведомления через обычную службу уведомлений Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Диагностика уведомлений доступна только на Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Диагностика уведомлений станет доступна после запуска координатора календаря.';

  @override
  String get developerNotificationRefresh => 'Обновить диагностику';

  @override
  String get developerNotificationSystemStatus =>
      'Системное разрешение на уведомления';

  @override
  String get developerNotificationPermissionAllowed => 'Разрешено';

  @override
  String get developerNotificationPermissionBlocked => 'Заблокировано';

  @override
  String get developerNotificationExactAlarm => 'Точные сигналы';

  @override
  String get developerNotificationExactAlarmAllowed => 'Разрешены';

  @override
  String get developerNotificationExactAlarmBlocked => 'Не разрешены';

  @override
  String get developerNotificationPlan => 'План уведомлений календаря';

  @override
  String get developerNotificationCoverage => 'Охват';

  @override
  String get developerNotificationCoverageReady =>
      'Все известные напоминания с конечным числом повторов запланированы напрямую';

  @override
  String get developerNotificationCoverageRenewable =>
      'Повторяющиеся напоминания перепланируются по возможности для долгосрочного охвата';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Лимит прямого планирования сигналов достигнут; последующие напоминания перепланируются по возможности';

  @override
  String get developerNotificationCoverageBlocked =>
      'Условия точной доставки не выполнены';

  @override
  String get developerNotificationCoverageFailed =>
      'Последняя синхронизация напоминаний завершилась ошибкой';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return 'Прямых сигналов: $scheduled / лимит: $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return 'Запланировано: $scheduled, в плане: $planned';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Последняя ошибка: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Перестроить план уведомлений';

  @override
  String get developerNotificationMaintenanceComplete =>
      'План уведомлений перестроен.';

  @override
  String get developerNotificationTestChannel => 'Тестовый канал';

  @override
  String get developerNotificationTestCourse => 'Напоминания о занятиях';

  @override
  String get developerNotificationTestSchedule => 'Напоминания календаря';

  @override
  String get developerNotificationImmediateTest => 'Отправить тест сейчас';

  @override
  String get developerNotificationThirtySecondTest =>
      'Запланировать фоновый тест через 30 секунд';

  @override
  String get developerNotificationImmediateQueued =>
      'Мгновенное тестовое уведомление отправлено.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Фоновый тест запланирован через 30 секунд.';

  @override
  String get developerNotificationAppSwitch =>
      'Переключатель напоминаний в приложении';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Обычные напоминания включены';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Обычные напоминания отключены; тесты разработчика по-прежнему доступны';

  @override
  String get developerNotificationTimeZone => 'Местный часовой пояс';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Ещё не создан. Он будет создан при тесте разработчика.';

  @override
  String get developerNotificationChannelEnabledState => 'Включён';

  @override
  String get developerNotificationChannelBlockedState => 'Заблокирован';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Важность: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Важность недоступна';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return 'Ожидает: $pending / активно: $active';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Последний показ системой: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Пересчёты ещё не зарегистрированы.';

  @override
  String get developerNotificationNextReminder =>
      'Следующее настоящее напоминание';

  @override
  String get developerNotificationNoPendingReminder =>
      'В текущем плане нет будущих напоминаний';

  @override
  String get developerNotificationNextMaintenance => 'Следующее обслуживание';

  @override
  String get developerNotificationNextRenewal =>
      'Следующая попытка перепланирования';

  @override
  String get developerNotificationNoMaintenance => 'Не запланировано';

  @override
  String get developerNotificationTruncation => 'Обрезка плана';

  @override
  String developerNotificationTruncationCount(int count) {
    return 'Пропущено из-за лимита плана: $count';
  }

  @override
  String get developerNotificationLastReconciliation => 'Последний пересчёт';

  @override
  String get developerNotificationLastSynchronization =>
      'Последняя синхронизация напоминаний';

  @override
  String get developerNotificationLateRecovery =>
      'Восстановление запоздавших напоминаний';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return 'Восстановлено напоминаний после назначенного времени: $count';
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
  String get developerNotificationReconcileOriginForeground => 'Передний план';

  @override
  String get developerNotificationReconcileOriginBackground => 'Фон';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Полный пересчёт';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Обслуживание';

  @override
  String get developerNotificationReconcileModeRecovery => 'Восстановление';

  @override
  String get developerNotificationRunRecovery => 'Восстановить напоминания';

  @override
  String get developerNotificationRecoveryComplete =>
      'Восстановление напоминаний завершено';

  @override
  String get developerNotificationReconcileResultSuccess => 'Успешно';

  @override
  String get developerNotificationReconcileResultSkipped => 'Пропущено';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Заблокировано до выполнения всех условий точной доставки';

  @override
  String get developerNotificationReconcileResultFailed => 'Ошибка';

  @override
  String get developerNotificationBackgroundLimits =>
      'Фоновые ограничения производителя';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Фоновые ограничения производителя могут влиять на доставку.';

  @override
  String get developerNotificationAutostart => 'Фоновый запуск производителя';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Производитель: $vendor; доступен переход к настройкам производителя. Android не предоставляет состояние этого разрешения.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Производитель: $vendor; вместо его настроек используются сведения о приложении. Android не предоставляет состояние этого разрешения.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Нет доступного перехода к фоновым настройкам производителя.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Последний открытый раздел: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'настройки производителя';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'сведения о приложении';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'нет';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Ограничения восстановления после перезагрузки';

  @override
  String get developerNotificationRebootBoundary =>
      'Восстановление начинается после первой разблокировки; принудительно остановленное приложение не может запуститься самостоятельно.';

  @override
  String get developerNotificationTestChecking =>
      'Тесты недоступны во время проверки состояния уведомлений.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Тесты недоступны, поскольку системные уведомления заблокированы.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Тесты недоступны, поскольку выбранный канал уведомлений заблокирован.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Управляется настройками уведомлений Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Не применяется в Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Идентификатор пакета Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Идентификатор MSIX доступен; показанные уведомления можно удалять';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Установите версию MSIX для надёжного удаления показанных уведомлений';

  @override
  String get collapseWorkspaceNavigation =>
      'Свернуть навигацию рабочего пространства';

  @override
  String get expandWorkspaceNavigation =>
      'Развернуть навигацию рабочего пространства';

  @override
  String get schoolWebImportExitBrowser => 'Выйти из встроенного браузера';

  @override
  String get schoolWebImportEditAddress => 'Изменить адрес';

  @override
  String get schoolWebImportAddressLabel => 'Веб-адрес';

  @override
  String get schoolWebImportOpenAddress => 'Открыть';

  @override
  String get schoolWebImportAddressInvalid =>
      'Введите адрес HTTP или HTTPS с именем хоста.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Эта веб-страница запросила новое окно, которое нельзя открыть на этом устройстве.';

  @override
  String get schoolWebImportSecureConnection => 'Защищённое соединение';

  @override
  String get schoolWebImportInsecureConnection => 'Незащищённое соединение';

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
  String get notificationSettingsSection => 'Напоминания и уведомления';

  @override
  String get notificationCoverage => 'Охват напоминаний';

  @override
  String get notificationCoverageRenewable =>
      'Повторяющиеся события без даты окончания перепланируются в фоне для долгосрочного охвата.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android может напрямую запланировать до $capacity напоминаний; приложение пытается заранее перепланировать последующие.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Включить напоминания и уведомления';

  @override
  String get notificationSettingsEnabledHint =>
      'Уведомления планируются только для элементов с напоминанием. Ниже задайте напоминание по умолчанию для предметов, которые его наследуют.';

  @override
  String get notificationPrecisionLimitations =>
      'Напоминания зависят от разрешений системы и фоновой работы. Выключение, изменение времени и системные ограничения могут задержать доставку.';

  @override
  String get notificationSettingsEnabledSummary => 'Включены';

  @override
  String get notificationSettingsDisabledSummary => 'Отключены';

  @override
  String get notificationDefaultsSection => 'Напоминания по умолчанию';

  @override
  String get notificationCourseDefaultReminder =>
      'Напоминание о занятиях по умолчанию';

  @override
  String get notificationGeneralDefaultReminder =>
      'Напоминание календаря по умолчанию';

  @override
  String get notificationReminderOff => 'Без напоминания';

  @override
  String notificationReminderCustom(int minutes) {
    return 'За $minutes мин';
  }

  @override
  String get notificationPermission => 'Разрешение на уведомления';

  @override
  String get notificationPermissionGranted => 'Разрешено системой';

  @override
  String get notificationPermissionDenied => 'Заблокировано системой';

  @override
  String get notificationPermissionChecking => 'Проверка разрешения…';

  @override
  String get notificationPermissionRequest => 'Запросить разрешение';

  @override
  String get notificationPermissionOpenSettings =>
      'Открыть системные настройки';

  @override
  String get notificationPermissionRequestFailed =>
      'Не удалось проверить разрешение на уведомления. Повторите попытку.';

  @override
  String get notificationExactAlarm => 'Разрешение на точные сигналы';

  @override
  String get notificationExactAlarmAllowed => 'Разрешено системой';

  @override
  String get notificationExactAlarmRequired =>
      'Требуется для точного времени напоминаний';

  @override
  String get notificationExactAlarmRequest => 'Разрешить точные сигналы';

  @override
  String get notificationBatteryOptimization => 'Оптимизация батареи';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Добавлено в исключения оптимизации батареи Android';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Для точных напоминаний нужно исключение из оптимизации батареи Android';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Открыть настройки оптимизации батареи';

  @override
  String get notificationAutostart => 'Фоновый запуск производителя';

  @override
  String get notificationAutostartVendorHint =>
      'Разрешите автозапуск или работу в фоне, чтобы напоминания могли восстановиться после перезагрузки.';

  @override
  String get notificationAutostartFallbackHint =>
      'Откройте сведения о приложении Sked и разрешите работу в фоне. Android не может проверить эту настройку производителя.';

  @override
  String get notificationAutostartUnavailable =>
      'Страница настроек производителя не найдена. Проверьте сведения о приложении Sked вручную.';

  @override
  String get notificationAutostartRequest =>
      'Открыть фоновые настройки производителя';

  @override
  String get notificationAutostartOpenFailed =>
      'Не удалось открыть фоновые настройки производителя. Проверьте сведения о приложении Sked вручную.';

  @override
  String get notificationLockScreenTitles =>
      'Показывать заголовки на экране блокировки';

  @override
  String get notificationLockScreenTitlesHint =>
      'Если отключено, подробности уведомлений скрыты на экране блокировки.';

  @override
  String get notificationWidgets => 'Виджеты главного экрана';

  @override
  String get notificationWidgetsDesc =>
      'Обновите виджеты Sked и узнайте, как добавить их через главный экран.';

  @override
  String get notificationWidgetsDialogTitle => 'Добавить виджет Sked';

  @override
  String get notificationWidgetsDialogMessage =>
      'На главном экране устройства нажмите и удерживайте пустое место, выберите «Виджеты» и добавьте виджет Sked. Он покажет ближайшие занятия или события.';

  @override
  String get notificationWidgetsRefresh => 'Обновить виджеты';

  @override
  String get notificationWidgetsRefreshed => 'Виджеты обновлены';

  @override
  String get notificationPlatformUnsupported =>
      'Эта платформа не поддерживает нативные уведомления.';

  @override
  String get workspaceFeatures => 'Управление функциями';

  @override
  String get workspaceBoth => 'Учебное расписание и события';

  @override
  String get workspaceOnlyStudent => 'Только учебное расписание';

  @override
  String get workspaceOnlyGeneral => 'Только события';

  @override
  String get workspaceDisableTitle => 'Отключить это рабочее пространство?';

  @override
  String get workspaceDisableMessage =>
      'Данные и настройки сохранятся. Функции и напоминания будут остановлены, пока вы не включите пространство здесь снова.';

  @override
  String get workspaceEnableHint =>
      'Выберите нужные функции. Хотя бы одна должна оставаться включённой.';

  @override
  String get workspaceLastRequired =>
      'Хотя бы одно рабочее пространство должно оставаться включённым.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Рабочее пространство отключено, но напоминания удалить не удалось. Повторите восстановление уведомлений.';

  @override
  String get settingsSearch => 'Поиск настроек';

  @override
  String get settingsNoResults => 'Подходящие настройки не найдены';

  @override
  String get settingsDataPrivacy => 'Данные и конфиденциальность';

  @override
  String get workspacePreferences => 'Отображение и управление';

  @override
  String get workspaceManage => 'Управление';

  @override
  String get selectedDayAgenda => 'Выбранный день';

  @override
  String get notificationTroubleshooting => 'Разрешения и устранение неполадок';

  @override
  String get settingsConnection => 'Подключение';

  @override
  String get settingsAdvanced => 'Дополнительно';

  @override
  String get unsavedChangesMessage =>
      'Есть несохранённые изменения. Отменить их и выйти?';

  @override
  String get backupWorkspaceSelection =>
      'Полная резервная копия включает данные и выбор включённых рабочих пространств.';

  @override
  String get assistantLayoutPreview => 'ИИ · Предпросмотр компоновки';

  @override
  String get assistantSelectionContext =>
      'Использует текущее выделение как контекст';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Черновик сообщения';

  @override
  String get assistantPreviewNoSend =>
      'Только предпросмотр компоновки. Ничего не будет отправлено или изменено.';

  @override
  String get resizePanel => 'Изменить размер панели';

  @override
  String get minimizeWindow => 'Свернуть';

  @override
  String get maximizeWindow => 'Развернуть';

  @override
  String get restoreWindow => 'Восстановить окно';

  @override
  String get closeWindow => 'Закрыть окно';

  @override
  String get courseSystemReminder => 'Системное напоминание';

  @override
  String courseReminderInherit(String reminder) {
    return 'По умолчанию ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Системные напоминания отключены в настройках уведомлений. Настройку этого предмета всё равно можно сохранить.';

  @override
  String get courseReminderDefaultOff =>
      'Напоминание о занятиях по умолчанию не задано. Выберите своё напоминание здесь или задайте значение по умолчанию в настройках уведомлений.';

  @override
  String get courseReminderDeliveryHint =>
      'Эта настройка сохраняется вместе с предметом. Доставка зависит от системных разрешений на уведомления и фоновых ограничений.';

  @override
  String get courseReminderPermissionUnknown =>
      'Состояние системных уведомлений ещё не проверено. Проверьте настройки уведомлений, прежде чем полагаться на напоминания.';

  @override
  String get courseReminderMinutesLabel => 'За сколько минут до занятия';

  @override
  String get exportAction => 'Экспортировать';

  @override
  String get datePickerSelectWeek => 'Выберите неделю';

  @override
  String get datePickerSelectMonth => 'Выберите месяц';

  @override
  String get generalDateLabelFormatDescription =>
      'Применяется к навигации по датам на компьютерах и небольших экранах.';

  @override
  String get dateRangeTitle => 'Выберите диапазон дат';

  @override
  String get dateRangeCustom => 'Произвольный';

  @override
  String get dateRangeChooseStart => 'Выберите начальную дату';

  @override
  String get dateRangeChooseEnd => 'Выберите конечную дату';

  @override
  String get dateRangeLimit =>
      'Выберите от 1 до 14 дней, включая обе граничные даты.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дней',
      few: '$days дня',
      one: '1 день',
    );
    return 'Произвольный · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Выбрать прокруткой';

  @override
  String get courseReminderUseDefault => 'Использовать по умолчанию';

  @override
  String get courseReminderInvalidMinutes =>
      'Введите целое число минут, равное нулю или больше.';

  @override
  String get generalCustomColumnWidth => 'Ширина столбцов настраиваемого вида';

  @override
  String get generalCustomColumnWidthAuto => 'Автоматическая';

  @override
  String get generalCustomColumnWidthManual => 'Минимальная ширина';

  @override
  String get generalCustomColumnWidthMinimum => 'Минимальная ширина дня';

  @override
  String get generalCustomColumnWidthHint =>
      'Для всех дат используется одинаковая минимальная ширина. Столбцы заполняют доступное место или прокручиваются по горизонтали. Действует только для настраиваемого вида.';

  @override
  String get settingsAppearanceLanguage => 'Оформление и язык';

  @override
  String get settingsAppearanceDetails => 'Цвета и контуры';

  @override
  String get monthNoEvents => 'В этот день нет событий';

  @override
  String get settingsOverview => 'Обзор';

  @override
  String get settingsThemeTarget => 'Тема для';

  @override
  String get settingsColorMode => 'Цветовой режим';

  @override
  String get settingsNotificationPreferences => 'Настройки напоминаний';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Напоминания по умолчанию, разрешения и надёжность';

  @override
  String get settingsFeaturesSummary => 'Рабочие области и навигация';

  @override
  String get settingsPrivacySummary =>
      'Политика конфиденциальности и очистка локальных данных';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Занятий: $count',
      one: 'Занятий: 1',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Занятие';

  @override
  String get periodTimesDurationColumn => 'Длительность';

  @override
  String get periodTimesGapColumn => 'Перерыв';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes мин';
  }

  @override
  String get periodTimesSavePending => 'Ожидание сохранения…';

  @override
  String get periodTimesSaveFailed => 'Не сохранено · Ошибка сохранения';

  @override
  String get periodTimesInvalidStatus =>
      'Не сохранено · Исправьте выделенное время';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked не удалось подтвердить отмену последнего сохранения. Запись приостановлена, копии для восстановления сохранены. Проверьте хранилище и повторите загрузку.';

  @override
  String get settingsPanelDisplayMode => 'Отображение панелей';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Общее для расписаний и календарей';

  @override
  String get settingsPanelDisplayOverlay => 'Поверх';

  @override
  String get settingsPanelDisplaySideBySide => 'Рядом';

  @override
  String get settingsPanelDisplayAutomatic => 'Автоматически';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Показывает панель справа поверх календаря, не меняя его ширину.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Предпочитает размещение рядом; показывает поверх, только если календарь станет слишком узким.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Размещает рядом, если календарь остаётся читаемым, иначе показывает поверх.';

  @override
  String get toolbarNavigationEssentialHint =>
      'При отключении пунктов «Настройки» или «Рабочая область» на панели они перемещаются в «Ещё». Меню «Ещё» нельзя скрыть, пока в нём есть необходимые действия. Переключение рабочих областей появляется, только когда нижняя навигация скрыта и включено несколько рабочих областей.';

  @override
  String get reminderEnded => 'Завершено';

  @override
  String get reminderAutoCloseHint =>
      'Закроется через 10 секунд. Используйте панель, чтобы оставить её открытой.';

  @override
  String get showReminderIndependently => 'Открыть отдельно';

  @override
  String get categoryManagerTitle => 'Управление категориями';

  @override
  String get categoryHidden => 'Скрыта';

  @override
  String get categoryShowOnCalendar => 'Показать в календаре';

  @override
  String get categoryHideOnCalendar => 'Скрыть в календаре';

  @override
  String get categoryEditColor => 'Изменить цвет категории';

  @override
  String get categoryThemePalette => 'Палитра темы';

  @override
  String get categoryCustomColor => 'Свой цвет';

  @override
  String get colorHexInvalid =>
      'Введите шестизначный шестнадцатеричный код цвета.';

  @override
  String categoryColorSlot(int number) {
    return 'Цвет темы $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Обновления в магазине могут появляться позже. Доступность определяется страницей магазина.';

  @override
  String get storePrereleaseNotice =>
      'Получение уведомлений о предварительных версиях не подключает вас к тестовой программе магазина.';

  @override
  String get updateFoundTitle => 'Доступна новая версия';

  @override
  String get updateNoNotes => 'Примечания к выпуску не предоставлены.';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateRetry => 'Повторить';

  @override
  String get updatePrerelease => 'Предварительная версия';

  @override
  String get updateNetworkFailure =>
      'Не удалось проверить обновления. Проверьте подключение и повторите попытку.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Более новая версия не найдена (текущая: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Восстановление резервной копии…';

  @override
  String get backupRestoreInProgressMessage =>
      'Данные и настройки можно будет изменить после восстановления. Их по-прежнему можно просматривать.';
}
