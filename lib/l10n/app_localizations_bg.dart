// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get appTitle => 'Съученик';

  @override
  String weekLabel(int week) {
    return 'Седмица $week';
  }

  @override
  String get addCourse => 'Добавяне на курс';

  @override
  String get settings => 'Настройки';

  @override
  String get multiTimetableSwitch => 'Смяна на графиците';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Текущ график · $weeks седмици';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Докоснете, за да превключите · $weeks седмици';
  }

  @override
  String get editTimetable => 'Редактиране на графика';

  @override
  String get schoolImportResultEditorTitle => 'Edit parsed result';

  @override
  String get createTimetable => 'Нов график';

  @override
  String get jumpToWeek => 'Прескочи към седмицата';

  @override
  String get timetable => 'Разписание';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Име на графика';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Общо седмици';

  @override
  String get delete => 'Изтриване';

  @override
  String get cancel => 'Отмени';

  @override
  String get save => 'Запазване';

  @override
  String get deleteTimetableTitle => 'Изтриване на графика';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Изтриване на \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Все още няма график';

  @override
  String get noTimetableMessage =>
      'Създайте график или импортирайте един от JSON файл.';

  @override
  String get importTimetable => 'Внос на график';

  @override
  String get courseName => 'Име на курса';

  @override
  String get location => 'Местоположение';

  @override
  String get dayOfWeek => 'Ден';

  @override
  String get semesterWeeks => 'седмици';

  @override
  String get startTime => 'Стартно време';

  @override
  String get endTime => 'Крайно време';

  @override
  String get linkedPeriods => 'Свързани периоди';

  @override
  String get linkedPeriodsUnmatched =>
      'Няма съответстващи периоди за текущото време. Докоснете, за да изберете ръчно.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Период $start-$end';
  }

  @override
  String get teacherName => 'Учител';

  @override
  String get credits => 'Кредити';

  @override
  String get remarks => 'Забележки';

  @override
  String get customFields => 'Персонализирани полета';

  @override
  String get customFieldsHint => 'Един на ред, формат: ключ:стойност';

  @override
  String get more => 'Още';

  @override
  String get selectDayOfWeek => 'Изберете ден';

  @override
  String get selectSemesterWeeks => 'Изберете седмици';

  @override
  String get selectAll => 'Изберете всички';

  @override
  String get clear => 'Изчисти';

  @override
  String get confirm => 'Потвърди';

  @override
  String get selectLinkedPeriods => 'Изберете свързани периоди';

  @override
  String get addCourseTitle => 'Добавяне на курс';

  @override
  String get editCourseTitle => 'Редактиране на курса';

  @override
  String get editCourseTooltip => 'Редактиране на курса';

  @override
  String get place => 'Местоположение';

  @override
  String get time => 'Времето';

  @override
  String get notFilled => 'Не е попълнено';

  @override
  String get none => 'Няма';

  @override
  String get conflictCourses => 'Конфликтни курсове';

  @override
  String get locationNotFilled => 'Местоположение не е попълнено';

  @override
  String get setAsDisplayed => 'Задаване като показано';

  @override
  String get editThisCourse => 'Редактирайте този курс';

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
      'В момента няма наличен график за настройки.';

  @override
  String get semesterStartDate => 'Дата на начало на семестъра';

  @override
  String get periodTimeSets => 'Период за определяне на времето';

  @override
  String get noPeriodTimeAvailable => 'Няма зададено време за наличен период';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count периоди';
  }

  @override
  String get coursePopupDismissSetting =>
      'Позволи външно докосване за затваряне на изскачащия прозорец на курса';

  @override
  String get coursePopupDismissSettingHint =>
      'Изключването на това също забранява уволнението с плъзгане надолу.';

  @override
  String get preserveTimetableGaps => 'Запазване на празнините в графика';

  @override
  String get preserveTimetableGapsHint =>
      'Когато си почивате, празнините за обяд и почивка се срушават, така че по-късните класове се движат нагоре.';

  @override
  String get showPastEndedCourses => 'Показване на завършени курсове';

  @override
  String get showPastEndedCoursesHint =>
      'Покажи курсове, които вече са завършили от реалната текуща седмица с по-светло сив стил.';

  @override
  String get showFutureCourses => 'Показа бъдещи курсове';

  @override
  String get showFutureCoursesHint =>
      'Показвайте курсове, които не са активни тази седмица, но ще се появят в по-късните седмици с сив стил.';

  @override
  String get timetableDisplaySettings => 'Показване на график и взаимодействие';

  @override
  String get timetableDisplaySettingsDesc =>
      'Показване на курсове, оформление, жестове за седмици и бързо добавяне';

  @override
  String get showTimetableGridLines =>
      'Показване на линиите на мрежата на графика';

  @override
  String get showTimetableGridLinesHint =>
      'Контролирайте дали хоризонталните и вертикалните линии на мрежата са видими в графика.';

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
  String get liveCourseOutlineColor => 'Цвят на очертанието на курса';

  @override
  String get liveCourseOutlineColorHint =>
      'Изберете дали очертанията са насочени към текущия/следващия курс или всички показвани курсове на текущата страница.';

  @override
  String get liveCourseOutlineSettings => 'Описание на курса';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Конфигурирайте дали очертанието е активирано, какво насочва, дали следва цвета на темата и ефективния цвят на очертанието.';

  @override
  String get liveCourseOutlineEnabled => 'Включване на очертанието';

  @override
  String get liveCourseOutlineFollowTheme => 'Следвайте цвета на темата';

  @override
  String get liveCourseOutlineTarget => 'Очертаване на целта';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Текущ/следващ курс';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Всички показани курсове';

  @override
  String get liveCourseOutlineEffectiveColor => 'Ефективен цвят';

  @override
  String get liveCourseOutlineCustomColor => 'Персонализиран цвят на контура';

  @override
  String get liveCourseOutlineWidth => 'Ширина на контура';

  @override
  String get outlineWidthUnit => 'ПКС';

  @override
  String get language => 'Език';

  @override
  String get languagePageDescription =>
      'Изберете един от езиците, които наистина са налични в приложението.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'Английски';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Отговор на API';

  @override
  String get theme => 'Тема';

  @override
  String get themeFollowSystem => 'Следвайте системата';

  @override
  String get themeLight => 'Светлината';

  @override
  String get themeDark => 'Тъмно';

  @override
  String get themeColor => 'Цвят на темата';

  @override
  String get themeColorModeSingle => 'Цвят на една тема';

  @override
  String get themeColorModeColorful => 'Цветни';

  @override
  String get themeColorUiColors => 'Цветове на потребителския интерфейс';

  @override
  String get themeColorCourseColors => 'Цветове на курса';

  @override
  String get themeColorPrimary => 'Първичен';

  @override
  String get themeColorSecondary => 'Вторичен';

  @override
  String get themeColorTertiary => 'Третият';

  @override
  String get themeColorCourseText => 'Текст на курса';

  @override
  String get themeColorCourseTextAuto => 'Автоматична';

  @override
  String get themeColorCourseTextCustom => 'Персонализиран цвят';

  @override
  String get themeColorCourseColorsEmpty =>
      'Цветовете на курса ще бъдат генерирани след импортирането на график.';

  @override
  String get themeCustomColor => 'Персонализиран цвят';

  @override
  String get themeApplyCustomColor => 'Прилагане на цвят';

  @override
  String get themeApplySettings => 'Прилагане на настройки';

  @override
  String get dataImportExport => 'Внос и износ на данни';

  @override
  String get dataImportExportDesc =>
      'Импортиране на пълни данни или единични графици или експортиране на текущи/всички графици.';

  @override
  String get appBackupTitle => 'Архивиране и възстановяване на приложението';

  @override
  String get appBackupSubtitle =>
      'Архивирайте или възстановете разписания, графици, настройки и училищни сайтове. API ключовете не са включени.';

  @override
  String get appBackupSheetSubtitle =>
      'Пълното възстановяване заменя текущите данни на приложението. AI API ключовете се съхраняват в защитено хранилище и не се записват във файловете за архив.';

  @override
  String get restoreBackupFileTitle => 'Възстановяване от JSON файл';

  @override
  String get restoreBackupFileSubtitle =>
      'Изберете пълен архивен файл на Sked. Ще потвърдите преди възстановяване.';

  @override
  String get restoreBackupTextTitle => 'Поставяне на архивен JSON';

  @override
  String get restoreBackupTextSubtitle =>
      'Поставете пълен архив и възстановете текущите данни на приложението.';

  @override
  String get shareBackupTitle => 'Споделяне на архивен файл';

  @override
  String get shareBackupSubtitle =>
      'Експортирайте пълните данни на приложението като JSON. API ключовете се изключват.';

  @override
  String get saveBackupTitle => 'Запазване на архивен файл';

  @override
  String get saveBackupSubtitle =>
      'Запазете пълен архив на приложението в локален файл.';

  @override
  String get copyBackupTitle => 'Копиране на архивния текст';

  @override
  String get copyBackupSubtitle =>
      'Показва пълния архивен JSON, за да можете да го копирате или съхраните временно.';

  @override
  String get restoreBackupConfirmTitle => 'Възстановяване на пълен архив?';

  @override
  String get restoreBackupConfirmMessage =>
      'Това заменя всички текущи разписания, общи графици, настройки и училищни сайтове. API ключовете не се импортират от архиви; въведете ключа отново, преди да анализирате разписания.';

  @override
  String get restoreBackupConfirmAction => 'Възстановяване на архив';

  @override
  String get restoreBackupSuccessMessage =>
      'Пълният архив на приложението е възстановен. AI API ключовете трябва да се въведат отново.';

  @override
  String get restoreBackupFailureMessage =>
      'Възстановяването не бе успешно. Проверете съдържанието на архива и опитайте отново.';

  @override
  String get openSourceLicenses => 'Лицензи с отворен код';

  @override
  String get openSourceLicensesDesc =>
      'Вижте лицензите за зависимостите на Flutter и активите на иконите на приложенията.';

  @override
  String get checkForUpdates => 'Проверете за актуализации';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Вече на най-новата версия ($version)';
  }

  @override
  String get currentVersionLabel => 'Текуща версия';

  @override
  String get newVersionAvailable => 'Актуализация на разположение';

  @override
  String get latestVersionLabel => 'Последна версия';

  @override
  String get updateContentLabel => 'Подробности за актуализацията';

  @override
  String get officialWebsite => 'Официален сайт';

  @override
  String get googlePlay => 'на Google Play';

  @override
  String get cloudDrive => 'Облачно устройство';

  @override
  String get ignoreThisVersion => 'Игнориране на тази версия';

  @override
  String get openUpdatesFailed =>
      'Не може да се отвори връзката за актуализация';

  @override
  String get updateCheckFailedTitle => 'Проверка на актуализацията не успя';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'GitHub хранилище';

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
      'Не може да се отвори връзката към хранилището на GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Не може да се отвори връзката към политиката за поверителност';

  @override
  String get selectPeriodTimeSet => 'Изберете определен период от време';

  @override
  String get newItem => 'Нови';

  @override
  String get editPeriodTimeSet => 'Редактиране на зададеното време за периода';

  @override
  String get importTimetableFiles => 'Внос на график';

  @override
  String get importTimetableFilesDesc =>
      'Поддържа един или няколко файла с график.';

  @override
  String get importTimetableText => 'Импортиране на график от текст';

  @override
  String get importTimetableTextDesc =>
      'Поставете JSON съдържанието на графика и го импортирайте.';

  @override
  String get shareTimetableFiles => 'Споделяне на графични файлове';

  @override
  String get shareTimetableFilesDesc =>
      'Първо изберете един или повече графици.';

  @override
  String get saveTimetableFiles => 'Запазване на графични файлове';

  @override
  String get saveTimetableFilesDesc =>
      'Първо изберете един или повече графици.';

  @override
  String get exportTimetableText => 'Експортиране на график като текст';

  @override
  String get exportTimetableTextDesc =>
      'Изберете един или повече графици, след което копирайте съдържанието на JSON.';

  @override
  String get jsonContent => 'JSON съдържание';

  @override
  String get pasteJsonContentHint =>
      'Поставете съдържанието на JSON за импортиране.';

  @override
  String get jsonContentEmpty => 'Първо поставете JSON съдържание.';

  @override
  String get copyText => 'Копиране';

  @override
  String get copiedToClipboard => 'Копиране в клипборда';

  @override
  String get share => 'Споделяне';

  @override
  String get selectTimetablesToExport => 'Изберете графици за експорт';

  @override
  String get selectTimetablesToImport => 'Изберете графици за импортиране';

  @override
  String timetableCourseCount(int count) {
    return '$count курсове';
  }

  @override
  String get importAction => 'Внос';

  @override
  String get importTimetableDialogTitle => 'Внос на график';

  @override
  String get chooseImportMethod => 'Изберете как да импортирате.';

  @override
  String get importAsNewTimetable => 'Импортиране като нов график';

  @override
  String get replaceCurrentTimetable => 'Замени текущия график';

  @override
  String get importPeriodTimeSetDialogTitle =>
      'Внос на часови набори за периода';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Този файл съдържа набори от периоди. Искате ли да ги импортирате и свързвате?';

  @override
  String get importBundledPeriodTimeSets => 'Внос и асоцииране';

  @override
  String get discardBundledPeriodTimeSets => 'Изхвърляне на пакетите';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Няма наличен набор от периодични времена, така че пакетите от периодични времена не могат да бъдат изхвърлени.';

  @override
  String savedToPath(Object path) {
    return 'Запазен в $path';
  }

  @override
  String get saveCancelled => 'Запазване отменено';

  @override
  String get fileSaveRestrictedTitle => 'Запазването на файлове е ограничено';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Системата не може да запази файла. Можете да опитате отново или да използвате споделяне вместо това.';

  @override
  String get retrySave => 'Опитайте отново да запишете';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Активирайте достъпа до файлове в системните настройки, след това се върнете и опитайте отново да експортирате.';

  @override
  String get openSettings => 'Отворете настройки';

  @override
  String get browserDownloadRestrictedTitle =>
      'Ограничено изтегляне на браузър';

  @override
  String get browserDownloadRestrictedMessage =>
      'Този браузър не поддържа пряко записване в локален файл. Проверете разрешенията за изтегляне на браузъра или използвайте споделяне на файлове вместо това.';

  @override
  String get switchToShare => 'Използвайте споделяне вместо това';

  @override
  String get fileSaveFailedTitle => 'Записването на файла не успя';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Не може да се запише в текущия път. Целтовата папка може да е защитена, файлът може да се използва или пътят може да не се записва.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Системата не може да запази файла. Можете да опитате отново, да проверите системните настройки или вместо това да използвате споделяне на файлове.';

  @override
  String get retryLater => 'Опитайте отново по-късно';

  @override
  String get exportSwitchedToShare =>
      'Прехвърлено към споделяне на файлове за експорт';

  @override
  String get saveFailedRetry =>
      'Записването се провали. Моля опитайте отново по-късно.';

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
  String get appInstanceBlockedTitle => 'Sked вече е отворен';

  @override
  String get appInstanceBlockedMessage =>
      'Друг прозорец на Sked или раздел на браузъра използва локалните ви данни. Затворете го и опитайте отново.';

  @override
  String get appInstanceLeaseFailedTitle => 'Локалните данни не са достъпни';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked не можа да потвърди изключителен достъп до локалните данни. Данните ви не бяха отворени или променени. Проверете достъпа до хранилището и опитайте отново.';

  @override
  String get savingChanges => 'Запазване на промените...';

  @override
  String get showApiKey => 'Показване на API ключа';

  @override
  String get hideApiKey => 'Скриване на API ключа';

  @override
  String get importFailedCheckContent =>
      'Импортирането се провали. Моля проверете съдържанието на файла.';

  @override
  String get noImportableTimetables =>
      'В импортирания файл не са намерени използвани графици.';

  @override
  String importedTimetablesCount(int count) {
    return 'Внесени $count графици';
  }

  @override
  String get periodTimesTitle => 'Период време';

  @override
  String get importExport => 'Внос и износ';

  @override
  String get importPeriodTemplate => 'Шаблон за период на внос';

  @override
  String get importPeriodTemplateText =>
      'Импортиране на шаблон за период от текст';

  @override
  String get sharePeriodTemplate => 'Шаблон за период на акции';

  @override
  String get saveTemplateToFile => 'Запазване на шаблона във файл';

  @override
  String get exportPeriodTemplateText =>
      'Експортиране на шаблон за период като текст';

  @override
  String get deletePeriodTimeSet => 'Изтриване на зададеното време за периода';

  @override
  String get periodTimeSetName => 'Име на зададеното време за периода';

  @override
  String get addOnePeriod => 'Добавяне на период';

  @override
  String periodNumberLabel(int index) {
    return 'Период $index';
  }

  @override
  String get deleteThisPeriod => 'Изтрийте този период';

  @override
  String durationMinutes(int minutes) {
    return 'Продължителност $minutes мин';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Разстояние от предишния $minutes мин';
  }

  @override
  String get endTimeMustBeLater =>
      'Крайното време трябва да е по-късно от началното';

  @override
  String get periodOverlapPrevious => 'Този период се припокрива с предишния';

  @override
  String get periodTimesSaved => 'Спасени периоди';

  @override
  String get deletePeriodTimeSetTitle =>
      'Изтриване на зададеното време за периода';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Изтриване на \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'зададено време за текущия период';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Внесени $count периодични времена';
  }

  @override
  String get periodFilePermissionTitle => 'Необходими разрешения за файлове';

  @override
  String get androidFilePermissionMessage =>
      'Експортът на Android изисква разрешение за достъп до файлове. Дайте разрешение да продължите да спестявате.';

  @override
  String get reauthorize => 'Авторизиране отново';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Постоянно отказано разрешение';

  @override
  String get permissionSettingsExportMessage =>
      'Активирайте достъпа до файлове в системните настройки, след това се върнете и опитайте отново да експортирате.';

  @override
  String get privacyPolicyTitle => 'Политика за поверителност';

  @override
  String get privacyPolicyEntryDesc =>
      'Научете как приложението се справя с локалното съхранение, конфигурацията на училището, импорта/експорта на файлове, анализа на уеб страници и външните връзки.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Приета версия: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked е локално-приоритетен инструмент за графици. Графиците, наборите от периоди и конфигурацията на училищния сайт се съхраняват само на вашето устройство или в браузъра ви и никога не се качват автоматично. Приложението обработва данни само когато изрично стартирате действия като импортиране, анализиране на уеб страници, споделяне или отваряне на външни връзки. Пълната политика за поверителност е достъпна онлайн.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Местно съхранение';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Внос и износ';

  @override
  String get privacyPolicyImportExportBody =>
      'Приложението чете или записва JSON файлове с график, JSON файлове с училищен сайт и файлове с шаблони за периоди само когато изрично изберете файл или започнете действие за експортиране. Импортирането на тези файлове е локална операция, освен ако не изберете и анализиране на уеб страници. Вземането на списък с персонализирани модели също е изрично мрежово действие и се свързва само с персонализираната крайна точка, която сте конфигурирали.';

  @override
  String get privacyPolicySharingTitle => 'Споделяне';

  @override
  String get privacyPolicySharingBody =>
      'Когато изрично използвате споделяне, приложението предава експортирания файл на листа за споделяне на системата или на избраното от вас целево приложение. Как се обработва този файл след това зависи от избраното от вас целево приложение или услуга.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Външни връзки';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Когато отворите външни връзки като хранилището на GitHub, приложението предава действието на вашия браузър или друго външно приложение. Обработката на данните след този момент се регулира от третата страна, която откривате.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Какво приложението не събира';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Приложението не изисква акаунт за Sked и не позволява анализи, рекламни идентификатори или резервно копиране в облака. Също така не предоставя специално поле за събиране на пароли за училищни акаунти. Ако влезете в училищен уебсайт в приложението, това взаимодействие се случва на страницата на училището, която сте отворили.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Парсиране на уеб страници';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Когато използвате импортиране от училищна уеб страница или анализирате поставен текст на разписание / HTML, приложението първо подготвя и почиства съдържанието локално, след което изпраща подадения текст на разписанието, текста на страницата или HTML съдържанието, незадължителното заглавие и URL на страницата, текущия език на приложението и инструкциите за анализатора към конфигурираната от вас OpenAI-съвместима крайна точка. Извличането на списъка с модели също заявява същата крайна точка. Sked не предоставя вградена крайна точка за анализ и не изпраща заявки за анализ към бекенд за разписания, контролиран от разработчика. Персонализираната крайна точка и всички услуги нагоре по веригата може да съхраняват, препращат, ограничават, изтриват или обработват данните по друг начин според правилата на избрания от вас доставчик. Ако използвате http:// Base URL, използвайте го само на надеждни устройства, мрежи и услуги за крайна точка, защото съдържанието и API ключовете може да не са защитени с транспортно криптиране.';

  @override
  String get privacyPolicyUpdatesTitle => 'Актуализации на политиката';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Настоящата версия на политиката за поверителност е $version. Ако по-късна версия промени начина, по който се обработват данните, приложението може да ви помоли да прочетете и да се съгласите отново с актуализираната политика.';
  }

  @override
  String get privacyGateTitle =>
      'Моля, съгласете се с политиката за поверителност преди да използвате приложението';

  @override
  String get privacyGateSummaryStorage =>
      'Разписанията, наборите от периоди и конфигурацията на училището се съхраняват само локално и не се качват автоматично на сървър на разработчика.';

  @override
  String get privacyGateSummaryImportExport =>
      'Импортирането, експортирането и споделянето се случват само когато изрично ги стартирате; анализирането на уеб страници изпраща само компресираното съдържание, което изпращате на конфигурираната крайна точка за анализиране, и можете да прегледате анализирания график, преди да го запишете.';

  @override
  String get privacyGateSummaryUpdates =>
      'Ако по-нова версия промени начина, по който се обработват данните, приложението може да ви помоли да прегледате отново актуализираната политика за поверителност.';

  @override
  String get schoolWebImportEntry => 'Импортиране от уебсайта на училището';

  @override
  String get schoolWebImportEntryDesc =>
      'Импортирайте текущата страница с график от сайта на училището.';

  @override
  String get schoolSitesManageEntry => 'Управление на училищните сайтове';

  @override
  String get schoolSitesManageEntryDesc =>
      'Добавяне, редактиране и изтриване на URL адреси за влизане в училище, с импортиране и експортиране на JSON.';

  @override
  String get schoolSitesPageTitle => 'Управление на училището';

  @override
  String get schoolSitesImportJson => 'Импортиране на JSON на училището';

  @override
  String get schoolSitesShareJson => 'Споделяне на училище JSON';

  @override
  String get schoolSitesSaveJson => 'Запазване на училището JSON';

  @override
  String get schoolSitesSaved => 'Спасени училищни сайтове';

  @override
  String get schoolSitesImported => 'Училищни сайтове, внесени';

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
  String get schoolSitesEmpty => 'Все още няма конфигурация на училището.';

  @override
  String get schoolSitesNameLabel => 'Име на училището';

  @override
  String get schoolSitesLoginUrlLabel => 'URL за влизане';

  @override
  String get schoolSitesAdd => 'Добавяне на училище';

  @override
  String get schoolSitesEdit => 'Редактиране на училище';

  @override
  String get schoolSitesDeleteTitle => 'Изтриване на училище';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Изтриване на \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Първо попълнете името на училището и URL адреса за влизане.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Импортиране чрез поставяне на съдържанието на страницата на графика';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Поставете изходния код или суровото съдържание на страницата, съдържащо информация за графика ръчно.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Анализиране на графика от съдържанието на страницата';

  @override
  String get schoolHtmlImportUrlLabel => 'URL на източника (незадължително)';

  @override
  String get schoolHtmlImportTitleLabel =>
      'Заглавие на страницата (незадължително)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Съдържание на страницата';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Поставете изходния код или суровото съдържание на страницата, съдържащо информация за графика тук.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Всяко съдържание, съдържащо информация за графика, може да бъде анализирано и импортирано, а не само HTML.';

  @override
  String get schoolHtmlImportCompress => 'Подготовка на съдържанието';

  @override
  String get schoolHtmlImportCompressed => 'Съдържанието е подготвено';

  @override
  String get schoolHtmlImportCompressFirst => 'Първо подгответе съдържанието.';

  @override
  String get schoolHtmlImportSubmit => 'Анализ и импортиране';

  @override
  String get schoolImportContentTruncated =>
      'Тази страница достигна безопасния лимит за импортиране. Само заснетата част ще бъде изпратена за анализиране.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Парсирането може да отнеме известно време. Моля те, изчакай.';

  @override
  String get schoolHtmlImportEmpty => 'Първо поставете HTML страницата.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Обратно към уебсайта';

  @override
  String get schoolWebImportPageTitle => 'Импортиране на училищни уеб страници';

  @override
  String get schoolWebImportPreview => 'Импортиране на предварителен преглед';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count курсове';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return ' $count периоди';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Заглавие на страницата';

  @override
  String get schoolWebImportParserUsed => 'Парсер';

  @override
  String get schoolWebImportWarnings => 'Внос на бележки';

  @override
  String get schoolWebImportParserDetails => 'Подробности за анализа';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Разгъване на подробностите за анализа';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Свиване на подробностите за анализа';

  @override
  String get schoolWebImportOpenPageHint =>
      'Влезте в сайта на училището в приложението, след което навигирайте ръчно към страницата с график.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Тази платформа все още не поддържа вградено уеб влизане. Моля, използвайте платформа с поддръжка на WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Изберете училище';

  @override
  String get schoolWebImportNoSchools =>
      'Няма налична конфигурация на училището. Първо проверете school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Грешка при зареждане на конфигурацията на училището. Проверете формата на файла JSON.';

  @override
  String get schoolWebImportImportCurrentPage =>
      'Импортиране на текуща страница';

  @override
  String get schoolWebImportLoadingPage => 'Страница се зарежда…';

  @override
  String get schoolWebImportParsing => 'Анализиране на текущата страница...';

  @override
  String get schoolWebImportLoadFailed =>
      'Страницата се зарежда неуспешно. Моля, освежете или опитайте отново по-късно.';

  @override
  String get schoolWebImportUnknownOrigin => 'Неизвестен сайт';

  @override
  String get schoolWebImportExitTitle => 'Изход от браузъра?';

  @override
  String get schoolWebImportExitMessage =>
      'Страницата ще се затвори. Всичко, което още не сте импортирали, ще бъде загубено.';

  @override
  String get schoolWebImportExitConfirm => 'Изход';

  @override
  String get schoolWebImportEmptyPage =>
      'Текущото съдържание на страницата е празно и все още не може да бъде импортирано.';

  @override
  String get schoolWebImportSuccess => 'Внесен уеб график';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Източник на анализатора';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Персонализиран OpenAI-съвместим';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Персонализиран OpenAI-съвместим анализатор';

  @override
  String get schoolImportParserCustomPromptTitle =>
      'Персонализирана инструкция';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Редактирайте вградената инструкция за анализиране тук. Промените засягат само персонализирания OpenAI-съвместим анализатор.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Вградената инструкция се зарежда тук по подразбиране. Изчистете го, за да се върнете към вградената версия.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Възстановяване на инструкцията по подразбиране';

  @override
  String get schoolImportParserBaseUrl => 'Базов URL адрес';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL трябва да е HTTP или HTTPS адрес с хост.';

  @override
  String get schoolImportParserApiKey => 'API ключ';

  @override
  String get schoolImportParserModel => 'модел';

  @override
  String get schoolImportParserFetchModels => 'Вземи списък с модели';

  @override
  String get schoolImportParserFetchingModels => 'Вземане на модели. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Не са върнати модели от крайната точка.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Моделите не можаха да бъдат извлечени. Проверете крайната точка и опитайте отново.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Взети $count модели';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Да се използва ли нешифрована HTTP крайна точка?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'API ключът и съдържанието на разписанието може да бъдат прочетени или променени при преноса. Продължете само ако имате доверие на това устройство, мрежа и крайна точка. Това разрешение важи, докато затворите Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Персонализираната конфигурация на анализатора е непълна. Първо попълнете базовия URL, API ключа и модела.';

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
    return 'Парсер: Персонализиран ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Вижте пълната политика за поверителност';

  @override
  String get privacyAgreeAndContinue => 'Съгласен и продължи';

  @override
  String get privacyDecline => 'Отхвърли';

  @override
  String get privacyDeclineWebHint =>
      'Тази среда на браузъра не позволява на приложението да затвори страницата за вас. Ако не сте съгласни, моля затворете този раздел или прозорец сами.';

  @override
  String get defaultPeriodTimeSetName => 'Периоди по подразбиране';

  @override
  String get periodTimeSetFallbackName => 'Период време';

  @override
  String get untitledTimetableName => 'Беззаглавен график';

  @override
  String get newTimetableName => 'Нов график';

  @override
  String get newPeriodTimeSetName => 'Нов период от време';

  @override
  String get emptyTimetableName => 'Празен график';

  @override
  String importedPeriodTimeSetName(Object name) {
    return ' $name периоди';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Типът на файла за импортиране не съвпада.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Тази версия на файла за импортиране все още не се поддържа.';

  @override
  String get noPeriodTimesInImportMessage =>
      'В файла за импортиране не са намерени периодични времена.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Моля изберете поне един график.';

  @override
  String get noExportableTimetableMessage => 'Няма график за износ.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Замяната на текущия график поддържа само избора на един график.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Няма актуален график за замена.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Този период от време все още се използва от $count график(и). Препоръчвайте ги преди да ги изтриете.';
  }

  @override
  String get weekdayMonday => 'Понеделник';

  @override
  String get weekdayTuesday => 'Вторник';

  @override
  String get weekdayWednesday => 'сряда';

  @override
  String get weekdayThursday => 'Четвъртък';

  @override
  String get weekdayFriday => 'Петък';

  @override
  String get weekdaySaturday => 'събота';

  @override
  String get weekdaySunday => 'Неделя';

  @override
  String get weekdayShortMonday => 'понеделник';

  @override
  String get weekdayShortTuesday => 'Вторник';

  @override
  String get weekdayShortWednesday => 'сряда';

  @override
  String get weekdayShortThursday => 'Четвъртък';

  @override
  String get weekdayShortFriday => 'Петък';

  @override
  String get weekdayShortSaturday => 'събота';

  @override
  String get weekdayShortSunday => 'Слънцето';

  @override
  String get monthJanuary => 'януари';

  @override
  String get monthFebruary => 'Февруари';

  @override
  String get monthMarch => 'Март';

  @override
  String get monthApril => 'април';

  @override
  String get monthMay => 'май';

  @override
  String get monthJune => 'юни';

  @override
  String get monthJuly => 'юли';

  @override
  String get monthAugust => 'август';

  @override
  String get monthSeptember => 'септември';

  @override
  String get monthOctober => 'октомври';

  @override
  String get monthNovember => 'ноември';

  @override
  String get monthDecember => 'декември';

  @override
  String get semesterWeeksWholeTerm => 'Целият семестър';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Седмици $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Седмици $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Изберете начален режим';

  @override
  String get firstLaunchSubtitle =>
      'Изберете работното пространство, което използвате най-често. Можете да смените режима по-късно.';

  @override
  String get firstLaunchStudentDesc =>
      'Управлявайте разписания, курсове, седмици, часове и импортиране.';

  @override
  String get firstLaunchGeneralDesc =>
      'Управлявайте категории, събития, напомняния и JSON / ICS данни.';

  @override
  String get firstLaunchStartStudent => 'Започни с разписание';

  @override
  String get firstLaunchStartGeneral => 'Започни с график';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'С избора на начално работно пространство потвърждавате, че сте прочели и приемате ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Политиката за поверителност';

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
  String get today => 'Днес';

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
      'Изгледи, лента с инструменти, формат на датата и бързо добавяне';

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
  String get viewWeek => 'Седмица';

  @override
  String get viewDay => 'Ден';

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
  String get developerModeTitle => 'Режим за разработчици';

  @override
  String get developerModeDescription =>
      'Инструменти за добавяне на пълни примерни данни за проверка на интерфейса и взаимодействията.';

  @override
  String get developerSampleLanguage => 'Език на примерните данни';

  @override
  String get developerSampleChinese => 'Китайски';

  @override
  String get developerSampleEnglish => 'Английски';

  @override
  String get developerSampleDataDescription =>
      'Добавя едно разписание и набор от категории и събития, без да заменя съществуващите данни.';

  @override
  String get developerAddSampleData => 'Добавяне на примерни данни';

  @override
  String get developerSampleDataAdded =>
      'Добавени са примерни данни за разписание и събития.';

  @override
  String get developerModeLongPressHint =>
      'Задръжте за 3 секунди, за да отворите режима за разработчици';

  @override
  String get collapseWorkspaceNavigation =>
      'Свиване на навигацията на работното пространство';

  @override
  String get expandWorkspaceNavigation =>
      'Разгъване на навигацията на работното пространство';

  @override
  String get schoolWebImportExitBrowser => 'Изход от вградения браузър';

  @override
  String get schoolWebImportEditAddress => 'Редактиране на адреса';

  @override
  String get schoolWebImportAddressLabel => 'Уеб адрес';

  @override
  String get schoolWebImportOpenAddress => 'Отваряне';

  @override
  String get schoolWebImportAddressInvalid =>
      'Въведете HTTP или HTTPS адрес с хост.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Тази уебстраница поиска нов прозорец, който не може да бъде отворен на това устройство.';

  @override
  String get schoolWebImportSecureConnection => 'Защитена връзка';

  @override
  String get schoolWebImportInsecureConnection => 'Незащитена връзка';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Да се отвори ли входът в училищната система?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Входът в училищната система може да изпрати идентификационни данни чрез формуляри или сървърни пренасочвания към училището и неговите доставчици за вход. Android не може да спре всяко такова предаване за отделно потвърждение на дестинацията. Продължете само ако имате доверие на тези страни за текущата сесия за импортиране:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Отваряне на незащитен вход за училището?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Този вход за училището използва HTTP. Всеки, който може да наблюдава или променя тази връзка, може да прочете или промени вашите идентификационни данни и съдържанието на страницата. Продължете само ако приемате този риск за:\n\n$origin';
  }
}
