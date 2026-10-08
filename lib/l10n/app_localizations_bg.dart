// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get appTitle => 'Sked';

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
  String get schoolImportResultEditorTitle =>
      'Редактиране на резултата от анализа';

  @override
  String get schoolImportParsePageTitle => 'Анализ на графика';

  @override
  String get schoolImportParsePageParsing => 'Анализиране…';

  @override
  String get schoolImportParsePageFailed => 'Анализът е неуспешен';

  @override
  String get schoolImportParsePageComplete => 'Анализът завърши';

  @override
  String get schoolImportParsePageContinue => 'Продължи';

  @override
  String get schoolImportParsePageRawContent => 'Необработен отговор';

  @override
  String get schoolImportParsePageExpandRaw =>
      'Разгъване на необработения отговор';

  @override
  String get schoolImportParsePageCollapseRaw =>
      'Свиване на необработения отговор';

  @override
  String get schoolImportExpandWarnings =>
      'Разгъване на предупрежденията при импортиране';

  @override
  String get schoolImportCollapseWarnings =>
      'Свиване на предупрежденията при импортиране';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Някои курсове продължават до седмица $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Да се замени ли текущото разписание?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Импортираното разписание ще замени текущото.';

  @override
  String get createTimetable => 'Нов график';

  @override
  String get jumpToWeek => 'Прескочи към седмицата';

  @override
  String get timetable => 'Разписание';

  @override
  String get themeWorkspaceSchedule => 'График';

  @override
  String get timetableName => 'Име на графика';

  @override
  String get timetableNameRequired => 'Въведете име на разписанието';

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
  String get settingsSectionTimetable => 'Разписание';

  @override
  String get settingsSectionGeneralSchedule => 'Общ график';

  @override
  String get settingsSectionAppearance => 'Облик';

  @override
  String get settingsSectionApp => 'Приложение';

  @override
  String get settingsSectionWorkspace => 'Работно пространство';

  @override
  String get settingsSectionAppearanceLanguage => 'Облик и език';

  @override
  String get settingsSectionDataSecurity => 'Данни и сигурност';

  @override
  String get settingsSectionAbout => 'Относно Sked';

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
      'Хоризонтално оформление и жестове';

  @override
  String get fitDaySelectorToWidth => 'Дните да се побират на екрана';

  @override
  String get fitDaySelectorToWidthHint =>
      'Показва всичките седем дни на екрана, когато е възможно. Изключете за фиксирана ширина и превъртане.';

  @override
  String get fitWeekColumnsToWidth =>
      'Седмичните колони да се побират на екрана';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Показва всичките седем колони на разписанието на екрана, когато е възможно. Изключете за фиксирана ширина и превъртане.';

  @override
  String get enableWeekSwipeNavigation => 'Смяна на седмицата с плъзгане';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Плъзнете наляво или надясно за друга седмица. При фиксирана ширина първо превъртете до края.';

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
  String get outlineWidthUnit => 'px';

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
  String get microsoftStoreUpdates =>
      'Актуализациите се управляват от Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Получаване на предварителни версии';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Включва версии Alpha, Beta и RC, които може да са нестабилни. При изключване се предлагат само стабилни версии.';

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
  String get googlePlay => 'Google Play';

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
      'Последната версия не може да се извлече от GitHub. Все пак можете да отворите GitHub Releases отдолу.';

  @override
  String get githubRepository => 'GitHub хранилище';

  @override
  String get googlePlayStoreDesc => 'Преглед на Sked в Google Play';

  @override
  String get openGooglePlayFailed => 'Google Play не може да се отвори';

  @override
  String get starSkedOnGithub => 'Дайте звезда на Sked в GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Отворете хранилището на проекта и дайте звезда на Sked';

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
  String get periodTimesUnsavedExitTitle => 'Промените не са запазени';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Последните промени в часовете не бяха запазени. Можете да опитате отново, да продължите редактирането или да ги отхвърлите.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Някои часове са невалидни. Поправете ги преди запазване или отхвърлете промените и излезте.';

  @override
  String get discardChangesAndExit => 'Отхвърляне и изход';

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
      'В нативните версии Sked съхранява разписанията, общите графици, свързаните настройки и конфигурацията на училищните сайтове в служебната папка на приложението, предоставена от операционната система. Браузърната версия използва хранилището на браузъра. Файловете, записани от по-стари версии в папката Документи, остават там, но не се прочитат или прехвърлят автоматично. За да запазите тези данни, експортирайте пълен архив от старата версия преди актуализиране и го възстановете след това. Настройките за AI API се пазят локално. Персонализираният API ключ се записва чрез защитеното хранилище на платформата, когато е налично. Пълните архиви не включват този ключ. Приложението не качва автоматично локалните данни на сървър, управляван от разработчика.';

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
  String get schoolSitesImportPreviewTitle =>
      'Преглед на импортираните училищни сайтове';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return 'Валидни сайтове: $validCount; невалидни записи: $invalidCount.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Файлът съдържа празен списък с училищни сайтове.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Запис $position е невалиден и ще бъде пропуснат.';
  }

  @override
  String get schoolSitesImportMerge => 'Обединяване';

  @override
  String get schoolSitesImportReplace => 'Замяна';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Да се заменят ли текущите училищни сайтове?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Това премахва текущите $currentCount сайта и запазва $importedCount импортирани сайта. Действието е необратимо.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Данните за училищните сайтове се нуждаят от възстановяване';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked не успя да прочете файла с училищните сайтове или архива му. Преди блокиране на записа бяха създадени защитени копия.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Хранилището за училищни сайтове е недостъпно';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'В момента Sked няма достъп до хранилището за училищни сайтове. Проверете достъпа до хранилището и наличността на устройството, след което опитайте отново. Текущите данни няма да бъдат презаписани.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'По-долу са показани файловете за възстановяване или засегнатите места за съхранение. Не променяйте файловете, докато списъкът със сайтове не бъде възстановен.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Начало без училищни сайтове';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Да се започне ли с празен списък със сайтове?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Защитените копия ще се запазят, но Sked ще създаде нов празен файл със сайтове. Продължете само ако не желаете първо да опитате възстановяване отново.';

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
      'Настройките на персонализирания анализатор са непълни. Първо въведете базов URL адрес, API ключ и модел.';

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
  String get schoolImportParserSettingsTitle =>
      'API за разчитане на разписания';

  @override
  String get schoolImportParserSettingsDesc =>
      'Настройте съвместимия с OpenAI API за импорт на разписания, а не за чат асистент.';

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
      'Персонализираният API ключ се записва чрез защитеното хранилище на платформата, когато е налично. Използвайте данните за достъп до анализатора и HTTP адресите само на устройства, в браузъри и мрежи, на които имате доверие.';

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
  String get clearAppData => 'Изчистване на данните';

  @override
  String get clearAppDataDesc =>
      'Окончателно изтриване на всички локални данни на Sked и изход';

  @override
  String get clearAppDataConfirmTitle =>
      'Да се изчистят ли всички данни на Sked?';

  @override
  String get clearAppDataConfirmMessage =>
      'Това изтрива окончателно разписанията, графиците, настройките, училищните сайтове, локалните архиви, копията за възстановяване и AI API ключа, след което затваря Sked. Файловете, експортирани на друго място, не се изтриват. Действието е необратимо.';

  @override
  String get clearAppDataAction => 'Изчистване и изход';

  @override
  String get clearAppDataFailed =>
      'Не всички локални данни бяха изчистени. Sked ще остане отворен, за да опитате отново.';

  @override
  String get clearAppDataExitFailed =>
      'Локалните данни бяха изчистени, но Sked не успя да се затвори. Затворете приложението ръчно, преди да го използвате отново.';

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
  String get generalSchedule => 'Общ график';

  @override
  String get studentTimetable => 'Учебно разписание';

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
  String get switchMode => 'Смяна на режима';

  @override
  String get generalScheduleComingSoon => 'Общият график идва скоро';

  @override
  String get switchToStudentTimetable => 'Към учебното разписание';

  @override
  String get mySchedule => 'Моят график';

  @override
  String get today => 'Днес';

  @override
  String get addEvent => 'Добавяне на събитие';

  @override
  String get editEvent => 'Редактиране на събитие';

  @override
  String get eventTitle => 'Заглавие';

  @override
  String get eventTitleRequired => 'Въведете заглавие';

  @override
  String get eventStartTime => 'Начален час';

  @override
  String get eventEndTime => 'Краен час';

  @override
  String get eventDate => 'Дата';

  @override
  String get eventTime => 'Час';

  @override
  String get eventNotes => 'Бележки';

  @override
  String get eventColor => 'Цвят';

  @override
  String get eventRecurrence => 'Повторение';

  @override
  String get recurrenceNone => 'Без повторение';

  @override
  String get recurrenceWeekly => 'Всяка седмица';

  @override
  String get recurrenceEndDate => 'Крайна дата';

  @override
  String get recurrenceNoEndDate => 'Без крайна дата';

  @override
  String get recurrenceSetEndDate => 'Задаване';

  @override
  String get recurrenceChangeEndDate => 'Промяна';

  @override
  String get repeatsWeekly => 'Повтаря се всяка седмица';

  @override
  String recurrenceUntil(Object date) {
    return 'До $date';
  }

  @override
  String get switchToGeneralSchedule => 'Към общия график';

  @override
  String get generalDisplaySettings => 'Настройки за показване на графика';

  @override
  String get generalDisplaySettingsDesc =>
      'Изгледи, лента с инструменти, формат на датата и бързо добавяне';

  @override
  String get closePopupOnOutsideTap =>
      'Затваряне при докосване извън прозореца';

  @override
  String get showGridLines => 'Показване на линиите на мрежата';

  @override
  String get generalScheduleImportExport =>
      'Импортиране и експортиране на категории';

  @override
  String get generalScheduleImportExportDesc =>
      'Импортиране или споделяне на категории от графика';

  @override
  String get importGeneralSchedules => 'Импортиране на категории';

  @override
  String get importGeneralSchedulesDesc =>
      'Прочитане на категории от JSON файл';

  @override
  String get shareGeneralSchedules => 'Споделяне на категории';

  @override
  String get shareGeneralSchedulesDesc =>
      'Споделяне на категории като JSON файл';

  @override
  String get saveGeneralSchedules => 'Запазване на категории';

  @override
  String get saveGeneralSchedulesDesc =>
      'Запазване на категории като JSON файл';

  @override
  String get selectSchedulesToExport => 'Избор на категории за експортиране';

  @override
  String get selectSchedulesToImport => 'Избор на категории за импортиране';

  @override
  String generalScheduleEventCount(int count) {
    return 'Събития: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Импортирани категории: $count';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Да се добави ли като нова категория, или да замени съществуваща?';

  @override
  String get addAsNewSchedule => 'Добавяне като нова категория';

  @override
  String get selectAtLeastOneScheduleMessage => 'Изберете поне една категория.';

  @override
  String get noExportableScheduleMessage => 'Няма категория за експортиране.';

  @override
  String get noSchedulesInImportMessage =>
      'Файлът за импортиране не съдържа категории.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Изберете точно една импортирана категория за замяната.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Избраната категория за замяна е недостъпна.';

  @override
  String get calendars => 'Категории';

  @override
  String get calendar => 'Категория';

  @override
  String get viewWeek => 'Седмица';

  @override
  String get viewDay => 'Ден';

  @override
  String get viewList => 'Списък';

  @override
  String get viewMonth => 'Месец';

  @override
  String visibleCategoryCount(int count) {
    return 'Категории: $count';
  }

  @override
  String get noVisibleCategories => 'Няма видими категории';

  @override
  String get selectCategoryToReplace => 'Избор на категория за замяна';

  @override
  String get replaceCategory => 'Замяна на категория';

  @override
  String get deleteEventTitle => 'Изтриване на събитие';

  @override
  String get deleteEventConfirmation =>
      'Това събитие ще бъде изтрито окончателно.';

  @override
  String get deleteRecurringEventTitle => 'Изтриване на повтарящо се събитие';

  @override
  String get eventDuplicated => 'Събитието е дублирано';

  @override
  String get searchEvents => 'Търсене на събития';

  @override
  String get clearSearch => 'Изчистване на търсенето';

  @override
  String get filterByColor => 'Филтриране по цвят';

  @override
  String get allColors => 'Всички цветове';

  @override
  String upcomingEventsCount(int count) {
    return 'Предстоящи: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'С изтекъл краен час: $count';
  }

  @override
  String get allDay => 'Целодневно';

  @override
  String get collapseAllDayTimeline => 'Свиване на целодневните събития';

  @override
  String get expandAllDayTimeline => 'Разгъване на целодневните събития';

  @override
  String allDayEventsCount(int count) {
    return 'Целодневни събития: $count';
  }

  @override
  String moreEvents(int count) {
    return '+ още $count';
  }

  @override
  String get noMatchingEvents => 'Няма съвпадащи събития';

  @override
  String get noUpcomingEvents => 'Няма предстоящи събития';

  @override
  String get addCalendar => 'Добавяне на категория';

  @override
  String get newCalendar => 'Нова категория';

  @override
  String get hideCalendar => 'Скриване на категория';

  @override
  String get showCalendar => 'Показване на категория';

  @override
  String get rename => 'Преименуване';

  @override
  String get renameCalendar => 'Преименуване на категория';

  @override
  String get name => 'Име';

  @override
  String get deleteCalendar => 'Изтриване на категория';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Да се изтрие ли „$name“?';
  }

  @override
  String get deleteThisOccurrence => 'Изтриване само на това повторение';

  @override
  String get deleteFutureOccurrences => 'Изтриване на това и следващите';

  @override
  String get deleteAllOccurrences => 'Изтриване на цялата поредица';

  @override
  String get duplicateEvent => 'Дублиране';

  @override
  String get repeatsDaily => 'Повтаря се всеки ден';

  @override
  String get repeatsMonthly => 'Повтаря се всеки месец';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Повтаря се през $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count пъти';
  }

  @override
  String get recurrenceDaily => 'Всеки ден';

  @override
  String get recurrenceMonthly => 'Всеки месец';

  @override
  String get recurrenceCustom => 'По избор';

  @override
  String get recurrenceEvery => 'На всеки';

  @override
  String get recurrenceUnit => 'Единица';

  @override
  String get recurrenceDays => 'дни';

  @override
  String get recurrenceWeeks => 'седмици';

  @override
  String get recurrenceMonths => 'месеци';

  @override
  String get recurrenceRepeatCount => 'Брой повторения';

  @override
  String get recurrenceNoLimit => 'Без ограничение';

  @override
  String get recurrencePositiveNumber => 'Въведете положително число';

  @override
  String get clearEndDate => 'Изчистване на крайната дата';

  @override
  String get pickDate => 'Избор на дата';

  @override
  String get pickTime => 'Избор на час';

  @override
  String get reminder => 'Напомняне в приложението';

  @override
  String get reminderAtStart => 'При започване';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes мин преди';
  }

  @override
  String get reminderHourBefore => '1 час преди';

  @override
  String get reminderDayBefore => '1 ден преди';

  @override
  String get markReminderHandled => 'Отбелязване като прегледано';

  @override
  String get restoreReminder => 'Възстановяване на напомнянето в приложението';

  @override
  String get reminderHandled =>
      'Напомнянето в приложението е отбелязано като прегледано';

  @override
  String get reminderRestored => 'Напомнянето в приложението е възстановено';

  @override
  String get reminderUpcoming => 'Предстоящо';

  @override
  String get reminderOverdue => 'С изтекъл краен час';

  @override
  String get generalFitWeekColumnsToWidth => 'Седмицата се побира на екрана';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Показва цялата седмица в компактен изглед. Изключете за хоризонтално превъртане. Периодите над 7 дни продължават да се превъртат.';

  @override
  String get showWeekends => 'Показване на събота и неделя';

  @override
  String get startHour => 'Начален час на изгледа';

  @override
  String get endHour => 'Краен час на изгледа';

  @override
  String get timeGridDensity => 'Интервал на часовата мрежа';

  @override
  String get timeGridHourHeight => 'Височина на един час';

  @override
  String get timeGridHourHeightHint =>
      'Променя вертикалния мащаб на дневния и седмичния изглед, без да променя интервала от 15, 30 или 60 минути.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Импортиране на JSON файл';

  @override
  String get pasteJson => 'Поставяне на JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Импортиране на категории от копиран JSON';

  @override
  String get importIcsFile => 'Импортиране на ICS файл';

  @override
  String get importIcsFileDesc =>
      'Прочитане на събития от календарен .ics файл';

  @override
  String get pasteIcs => 'Поставяне на ICS';

  @override
  String get pasteIcsDesc =>
      'Импортиране на събития от копиран календарен текст';

  @override
  String get copyJson => 'Копиране на JSON';

  @override
  String get copyJsonDesc => 'Копиране на избраните категории като JSON текст';

  @override
  String get shareIcs => 'Споделяне на ICS';

  @override
  String get shareIcsDesc => 'Споделяне на избраните календари като .ics';

  @override
  String get saveIcs => 'Запазване на ICS';

  @override
  String get saveIcsDesc => 'Запазване на избраните календари като .ics';

  @override
  String get copyIcs => 'Копиране на ICS';

  @override
  String get copyIcsDesc => 'Копиране на избраните календари като ICS текст';

  @override
  String get importIcs => 'Импортиране на ICS';

  @override
  String get icsContent => 'Съдържание на ICS';

  @override
  String get pasteIcsContentHint =>
      'Поставете тук съдържанието, започващо с BEGIN:VCALENDAR';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Намерени събития: $count. Да се добавят ли като нова категория, или да заменят съществуваща?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Импортирани категории: $count; предупреждения: $warningCount';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Пропуснато е събитие без начален час.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Пропуснато е събитие с неподдържан начален час.';

  @override
  String get importWarningAdjustedEnd =>
      'Коригиран е краен час, който не е след началния.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Неподдържаните ICS полета са добавени в бележките: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Пренебрегната е неподдържана честота на повторение: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Избор на календари за копиране като ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Избор на календари за експортиране като ICS';

  @override
  String get exportIcsText => 'Експортиране на ICS текст';

  @override
  String get exportJsonText => 'Експортиране на JSON текст';

  @override
  String get dataRestoredFromBackupNotice =>
      'Данните бяха възстановени от предишния архив, защото основният файл не се зареди.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Основният файл и архивът му са повредени. Приложението вече използва ново начално състояние.';

  @override
  String get dataRecoveryCorruptTitle => 'Данните се нуждаят от възстановяване';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked не успя да прочете основния файл или архива му. Преди блокиране на записа бяха създадени защитени копия.';

  @override
  String get dataRecoveryIoFailureTitle => 'Хранилището е недостъпно';

  @override
  String get dataRecoveryIoFailureMessage =>
      'В момента Sked няма достъп до локалното хранилище. Проверете достъпа до хранилището и наличността на устройството, след което опитайте отново. Съществуващите данни няма да бъдат презаписани.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Актуализирайте Sked, за да отворите тези данни';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Данните са създадени с по-нова версия на Sked. Актуализирайте приложението и опитайте отново. Започването отначало е забранено, за да се защитят данните.';

  @override
  String get dataRecoveryRetryAction => 'Повторен опит';

  @override
  String get dataRecoveryArtifactsHint =>
      'По-долу са показани файловете за възстановяване или засегнатите места за съхранение. Не променяйте файловете, докато данните не бъдат възстановени.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Показване на файловете и местата за възстановяване';

  @override
  String get dataRecoveryStartFreshAction => 'Начало с нови данни';

  @override
  String get dataRecoveryStartFreshConfirmTitle =>
      'Да се започне ли с нови данни?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Защитените копия ще се запазят, но Sked ще създаде нов локален файл с данни. Продължете само ако не желаете първо да опитате възстановяване отново.';

  @override
  String get previousMonth => 'Предишен месец';

  @override
  String get nextMonth => 'Следващ месец';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get reminderInProgress => 'В ход';

  @override
  String get deleteCourseTitle => 'Изтриване на курс';

  @override
  String get deleteCourseMessage => 'Да се изтрие ли този курс?';

  @override
  String get showLunarCalendar => 'Показване на лунния календар';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, събития: $count';
  }

  @override
  String get defaultView => 'Изглед по подразбиране';

  @override
  String get generalDefaultViewSection => 'При стартиране';

  @override
  String get generalViewSwitchBehavior => 'Бутон за смяна на изгледа';

  @override
  String get settingsWorkspaceMode => 'Активно работно пространство';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Скриване на навигацията между работните пространства';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Скрийте навигацията между работните пространства. Можете да ги сменяте от менюто на главния екран.';

  @override
  String get generalDateLabelFormat => 'Формат на етикета за дата';

  @override
  String get generalDateLabelFormatLocalized => 'Местен формат (юли 2026)';

  @override
  String get generalDateLabelFormatSlash => 'С наклонена черта (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Оформление на лентата с инструменти';

  @override
  String get toolbarNavigationSection => 'Навигация в лентата с инструменти';

  @override
  String get toolbarNavigationHiddenBehavior => 'Скрити елементи';

  @override
  String get toolbarNavigationRemove => 'Пълно скриване';

  @override
  String get toolbarNavigationMore => 'Преместване в „Още“';

  @override
  String get toolbarNavigationReorder => 'Подреждане на елементите в лентата';

  @override
  String get toolbarNavigationVisibility => 'Показване на елемент в лентата';

  @override
  String get toolbarNavigationTimetable => 'Избор на разписание';

  @override
  String get toolbarNavigationWeek => 'Избор на седмица';

  @override
  String get toolbarNavigationView => 'Смяна на изгледа';

  @override
  String get toolbarNavigationCategory => 'Избор на категория';

  @override
  String get toolbarNavigationDate => 'Избор на дата';

  @override
  String get generalToolbarWidthPolicy => 'Разпределение на мястото в лентата';

  @override
  String get generalToolbarWidthContent => 'Автоматично разпределение';

  @override
  String get generalToolbarWidthBalanced => 'Балансирано';

  @override
  String get generalToolbarWidthCalendarPriority => 'Приоритет на категорията';

  @override
  String get generalToolbarWidthDatePriority => 'Приоритет на датата';

  @override
  String get generalViewSwitchCycle => 'Последователна смяна на изгледите';

  @override
  String get generalViewSwitchMenu => 'Отваряне на менюто за изглед';

  @override
  String get generalViewSwitchTooltip => 'Смяна на изгледа';

  @override
  String get generalViewSwitchMenuTooltip => 'Избор на изглед';

  @override
  String get generalViewLongPressTodayHint =>
      'Задръжте за преминаване към днес';

  @override
  String get generalScheduleDisplaySection => 'Показване на графика';

  @override
  String get generalTimeGridSection => 'Часова мрежа';

  @override
  String get generalPopupSection => 'Поведение на изскачащите прозорци';

  @override
  String get quickActionsSection => 'Бързи действия';

  @override
  String get showAddCourseFab => 'Плаващ бутон за добавяне на курс';

  @override
  String get showAddCourseFabHint =>
      'Показва или скрива плаващия бутон за добавяне на курс в долния десен ъгъл на разписанието.';

  @override
  String get showAddEventFab => 'Плаващ бутон за добавяне на събитие';

  @override
  String get showAddEventFabHint =>
      'Показва или скрива плаващия бутон за добавяне на събитие в долния десен ъгъл на графика.';

  @override
  String get enableLongPressAddCourse =>
      'Добавяне на курс със задържане върху празна клетка';

  @override
  String get enableLongPressAddCourseHint =>
      'Задръжте върху празно място в мрежата на разписанието, за да добавите курс.';

  @override
  String get enableLongPressAddEvent =>
      'Добавяне на събитие със задържане върху празна клетка';

  @override
  String get enableLongPressAddEventHint =>
      'В дневния или седмичния изглед задръжте върху празно място в часовата мрежа, за да добавите събитие.';

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
  String get developerNotificationDiagnostics => 'Диагностика на известията';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Проверете състоянието на доставяне в Android, изградете отново плана за напомняния и изпратете безопасни тестови известия чрез обичайната услуга на Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Диагностиката на известията е достъпна само за Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Диагностиката ще стане достъпна, след като се стартира управлението на известията за графика.';

  @override
  String get developerNotificationRefresh => 'Обновяване на диагностиката';

  @override
  String get developerNotificationSystemStatus =>
      'Системно разрешение за известия';

  @override
  String get developerNotificationPermissionAllowed => 'Разрешено';

  @override
  String get developerNotificationPermissionBlocked => 'Блокирано';

  @override
  String get developerNotificationExactAlarm => 'Точни аларми';

  @override
  String get developerNotificationExactAlarmAllowed => 'Разрешени';

  @override
  String get developerNotificationExactAlarmBlocked => 'Неразрешени';

  @override
  String get developerNotificationPlan => 'План за известията от графика';

  @override
  String get developerNotificationCoverage => 'Покритие';

  @override
  String get developerNotificationCoverageReady =>
      'Всички известни напомняния с краен брой повторения са директно насрочени';

  @override
  String get developerNotificationCoverageRenewable =>
      'Повтарящите се напомняния се подновяват дългосрочно според възможностите на системата';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Лимитът за директни аларми е достигнат; следващите напомняния ще се подновяват според възможностите на системата';

  @override
  String get developerNotificationCoverageBlocked =>
      'Условията за точно доставяне не са изпълнени';

  @override
  String get developerNotificationCoverageFailed =>
      'Последното синхронизиране на напомнянията е неуспешно';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled директни аларми / капацитет $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return 'Насрочени: $scheduled, планирани: $planned';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Последна грешка: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Повторно изграждане на плана за известия';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Планът за известия е изграден отново.';

  @override
  String get developerNotificationTestChannel => 'Тестов канал';

  @override
  String get developerNotificationTestCourse => 'Напомняния за курсове';

  @override
  String get developerNotificationTestSchedule => 'Напомняния за събития';

  @override
  String get developerNotificationImmediateTest =>
      'Изпращане на незабавен тест';

  @override
  String get developerNotificationThirtySecondTest =>
      'Насрочване на фонов тест след 30 секунди';

  @override
  String get developerNotificationImmediateQueued =>
      'Незабавното тестово известие е изпратено.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Фоновият тест е насрочен след 30 секунди.';

  @override
  String get developerNotificationAppSwitch =>
      'Превключвател за напомняния в приложението';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Обичайните напомняния са включени';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Обичайните напомняния са изключени; тестовете за разработчици остават достъпни';

  @override
  String get developerNotificationTimeZone => 'Местна часова зона';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Все още не е създаден. Тест за разработчици ще го създаде.';

  @override
  String get developerNotificationChannelEnabledState => 'Включен';

  @override
  String get developerNotificationChannelBlockedState => 'Блокиран';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Важност: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Важността е недостъпна';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return 'Чакащи: $pending / активни: $active';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Последно системно показване: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Все още няма запис за преизчисляване.';

  @override
  String get developerNotificationNextReminder => 'Следващо реално напомняне';

  @override
  String get developerNotificationNoPendingReminder =>
      'Няма бъдещо напомняне в текущия план';

  @override
  String get developerNotificationNextMaintenance => 'Следваща поддръжка';

  @override
  String get developerNotificationNextRenewal => 'Следващ опит за подновяване';

  @override
  String get developerNotificationNoMaintenance => 'Не е насрочено';

  @override
  String get developerNotificationTruncation => 'Съкращаване на плана';

  @override
  String developerNotificationTruncationCount(int count) {
    return 'Пропуснати поради лимита на плана: $count';
  }

  @override
  String get developerNotificationLastReconciliation =>
      'Последно преизчисляване';

  @override
  String get developerNotificationLastSynchronization =>
      'Последна синхронизация на напомнянията';

  @override
  String get developerNotificationLateRecovery =>
      'Възстановяване на закъснели напомняния';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return 'След първоначалния им час бяха възстановени $count напомняния';
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
  String get developerNotificationReconcileOriginForeground => 'На преден план';

  @override
  String get developerNotificationReconcileOriginBackground => 'На заден план';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Пълно преизчисляване';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Поддръжка';

  @override
  String get developerNotificationReconcileModeRecovery => 'Възстановяване';

  @override
  String get developerNotificationRunRecovery =>
      'Възстановяване на напомнянията';

  @override
  String get developerNotificationRecoveryComplete =>
      'Възстановяването на напомнянията завърши';

  @override
  String get developerNotificationReconcileResultSuccess => 'Успешно';

  @override
  String get developerNotificationReconcileResultSkipped => 'Пропуснато';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Блокирано до изпълнение на всички условия за точно доставяне';

  @override
  String get developerNotificationReconcileResultFailed => 'Неуспешно';

  @override
  String get developerNotificationBackgroundLimits =>
      'Фонови ограничения на производителя';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Фоновите ограничения на производителя може да повлияят на доставянето.';

  @override
  String get developerNotificationAutostart =>
      'Фоново стартиране според производителя';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Производител: $vendor. Наличен е достъп до неговите настройки. Android не предоставя състоянието на това разрешение.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Производител: $vendor. Вместо това се отварят подробностите за приложението. Android не предоставя състоянието на това разрешение.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Няма достъпна страница с фонови настройки на производителя.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Последно отворена цел: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'настройки на производителя';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'подробности за приложението';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'няма';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Условия за възстановяване след рестартиране';

  @override
  String get developerNotificationRebootBoundary =>
      'Възстановяването започва след първото отключване. Принудително спряно приложение не може да се стартира само.';

  @override
  String get developerNotificationTestChecking =>
      'Тестовете са недостъпни, докато се проверява състоянието на известията.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Тестовете са недостъпни, защото системните известия са блокирани.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Тестовете са недостъпни, защото избраният канал за известия е блокиран.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Управлява се от настройките за известия на Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Не се отнася за Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Идентичност на пакета в Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Налична е MSIX идентичност; показаните известия могат да бъдат отменяни';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Инсталирайте MSIX версията за надеждно отменяне на показаните известия';

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

  @override
  String get notificationSettingsSection => 'Напомняния и известия';

  @override
  String get notificationCoverage => 'Покритие на напомнянията';

  @override
  String get notificationCoverageRenewable =>
      'Повтарящите се графици без крайна дата се подновяват във фонов режим за дългосрочно покритие.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android може директно да съхранява до $capacity напомняния. По-късните се подновяват предварително.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Включване на напомняния и известия';

  @override
  String get notificationSettingsEnabledHint =>
      'Насрочва само елементи с напомняне. Задайте по-долу стандартно напомняне за курсовете, които го наследяват.';

  @override
  String get notificationPrecisionLimitations =>
      'Напомнянията зависят от системните разрешения и работата във фонов режим. Изключване, промени в часа или системни ограничения могат да ги забавят.';

  @override
  String get notificationSettingsEnabledSummary => 'Включени';

  @override
  String get notificationSettingsDisabledSummary => 'Изключени';

  @override
  String get notificationDefaultsSection => 'Напомняния по подразбиране';

  @override
  String get notificationCourseDefaultReminder =>
      'Напомняне за курс по подразбиране';

  @override
  String get notificationGeneralDefaultReminder =>
      'Напомняне за събитие по подразбиране';

  @override
  String get notificationReminderOff => 'Без напомняне';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes минути преди';
  }

  @override
  String get notificationPermission => 'Разрешение за известия';

  @override
  String get notificationPermissionGranted => 'Разрешени от системата';

  @override
  String get notificationPermissionDenied => 'Блокирани от системата';

  @override
  String get notificationPermissionChecking => 'Проверка на разрешението…';

  @override
  String get notificationPermissionRequest => 'Искане на разрешение';

  @override
  String get notificationPermissionOpenSettings =>
      'Отваряне на системните настройки';

  @override
  String get notificationPermissionRequestFailed =>
      'Разрешението за известия не може да се прочете. Опитайте отново.';

  @override
  String get notificationExactAlarm => 'Разрешение за точни аларми';

  @override
  String get notificationExactAlarmAllowed => 'Разрешени от системата';

  @override
  String get notificationExactAlarmRequired =>
      'Необходимо за напомняния в точен час';

  @override
  String get notificationExactAlarmRequest => 'Разрешаване на точни аларми';

  @override
  String get notificationBatteryOptimization => 'Оптимизация на батерията';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Добавено е изключение от оптимизацията на батерията в Android';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Точните напомняния изискват изключение от оптимизацията на батерията в Android';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Отваряне на настройките за оптимизация на батерията';

  @override
  String get notificationAutostart => 'Фоново стартиране според производителя';

  @override
  String get notificationAutostartVendorHint =>
      'Разрешете автоматично стартиране или работа във фонов режим, за да могат напомнянията да се възстановят след рестартиране.';

  @override
  String get notificationAutostartFallbackHint =>
      'Отворете подробностите за Sked и разрешете работа във фонов режим. Android не може да провери тази настройка на производителя.';

  @override
  String get notificationAutostartUnavailable =>
      'Не е намерена страница с настройки на производителя. Проверете ръчно подробностите за Sked.';

  @override
  String get notificationAutostartRequest =>
      'Отваряне на фоновите настройки на производителя';

  @override
  String get notificationAutostartOpenFailed =>
      'Фоновите настройки на производителя не могат да се отворят. Проверете ръчно подробностите за Sked.';

  @override
  String get notificationLockScreenTitles =>
      'Показване на заглавия на заключения екран';

  @override
  String get notificationLockScreenTitlesHint =>
      'Когато е изключено, подробностите в известията се скриват на заключения екран.';

  @override
  String get notificationWidgets => 'Джаджи за началния екран';

  @override
  String get notificationWidgetsDesc =>
      'Обновете джаджите на Sked и вижте как да добавите джаджа от началния екран.';

  @override
  String get notificationWidgetsDialogTitle => 'Добавяне на джаджа на Sked';

  @override
  String get notificationWidgetsDialogMessage =>
      'Задръжте върху празно място на началния екран, изберете „Джаджи“ и добавете джаджа на Sked. Тя показва следващите ви курсове или събития.';

  @override
  String get notificationWidgetsRefresh => 'Обновяване на джаджите';

  @override
  String get notificationWidgetsRefreshed => 'Джаджите са обновени';

  @override
  String get notificationPlatformUnsupported =>
      'Тази платформа не предоставя системни известия.';

  @override
  String get workspaceFeatures => 'Управление на функциите';

  @override
  String get workspaceBoth => 'Учебна програма и събития';

  @override
  String get workspaceOnlyStudent => 'Само учебна програма';

  @override
  String get workspaceOnlyGeneral => 'Само събития';

  @override
  String get workspaceDisableTitle =>
      'Да се изключи ли това работно пространство?';

  @override
  String get workspaceDisableMessage =>
      'Данните и настройките ще се запазят. Функциите и напомнянията ще спрат, докато не го включите отново тук.';

  @override
  String get workspaceEnableHint =>
      'Изберете функциите, които използвате. Поне една трябва да остане включена.';

  @override
  String get workspaceLastRequired =>
      'Поне едно работно пространство трябва да остане включено.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Работното пространство е изключено, но напомнянията не бяха премахнати. Опитайте отново възстановяването на известията.';

  @override
  String get settingsSearch => 'Търсене в настройките';

  @override
  String get settingsNoResults => 'Няма съответстващи настройки';

  @override
  String get settingsDataPrivacy => 'Данни и поверителност';

  @override
  String get workspacePreferences => 'Изглед и взаимодействие';

  @override
  String get workspaceManage => 'Управление';

  @override
  String get selectedDayAgenda => 'Избран ден';

  @override
  String get notificationTroubleshooting =>
      'Разрешения и отстраняване на проблеми';

  @override
  String get settingsConnection => 'Връзка';

  @override
  String get settingsAdvanced => 'Разширени';

  @override
  String get unsavedChangesMessage =>
      'Имате незапазени промени. Да бъдат ли отхвърлени при излизане?';

  @override
  String get backupWorkspaceSelection =>
      'Пълното резервно копие включва данните и избора на включени работни пространства.';

  @override
  String get assistantLayoutPreview => 'AI · Преглед на оформлението';

  @override
  String get assistantSelectionContext =>
      'Използва текущия избор като контекст';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Чернова на съобщение';

  @override
  String get assistantPreviewNoSend =>
      'Само преглед на оформлението. Нищо няма да бъде изпратено или променено.';

  @override
  String get resizePanel => 'Промяна на размера на панела';

  @override
  String get minimizeWindow => 'Минимизиране';

  @override
  String get maximizeWindow => 'Максимизиране';

  @override
  String get restoreWindow => 'Възстановяване на прозореца';

  @override
  String get closeWindow => 'Затваряне на прозореца';

  @override
  String get courseSystemReminder => 'Системно напомняне';

  @override
  String courseReminderInherit(String reminder) {
    return 'По подразбиране ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Системните напомняния са изключени в настройките за известия. Предпочитанието за този курс все пак може да се запази.';

  @override
  String get courseReminderDefaultOff =>
      'Не е зададено стандартно напомняне за курсове. Изберете персонализирано тук или задайте стандартно в настройките за известия.';

  @override
  String get courseReminderDeliveryHint =>
      'Това предпочитание се запазва с курса. Доставянето зависи от системните разрешения за известия и фоновите ограничения.';

  @override
  String get courseReminderPermissionUnknown =>
      'Състоянието на системните известия не е проверено. Прегледайте настройките, преди да разчитате на напомнянията.';

  @override
  String get courseReminderMinutesLabel => 'Минути преди началото на курса';

  @override
  String get exportAction => 'Експортиране';

  @override
  String get datePickerSelectWeek => 'Избор на седмица';

  @override
  String get datePickerSelectMonth => 'Избор на месец';

  @override
  String get generalDateLabelFormatDescription =>
      'Важи за навигацията по дати на компютри и малки екрани.';

  @override
  String get dateRangeTitle => 'Избор на период';

  @override
  String get dateRangeCustom => 'По избор';

  @override
  String get dateRangeChooseStart => 'Изберете начална дата';

  @override
  String get dateRangeChooseEnd => 'Изберете крайна дата';

  @override
  String get dateRangeLimit =>
      'Изберете от 1 до 14 дни, включително началната и крайната дата.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дни',
      one: '1 ден',
    );
    return 'По избор · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Избор с колелца';

  @override
  String get courseReminderUseDefault => 'По подразбиране';

  @override
  String get courseReminderInvalidMinutes =>
      'Въведете цяло число минути, не по-малко от нула.';

  @override
  String get generalCustomColumnWidth =>
      'Ширина на колоните в персонализирания изглед';

  @override
  String get generalCustomColumnWidthAuto => 'Автоматично';

  @override
  String get generalCustomColumnWidthManual => 'Минимална ширина';

  @override
  String get generalCustomColumnWidthMinimum => 'Минимална ширина за ден';

  @override
  String get generalCustomColumnWidthHint =>
      'Всички дати използват еднаква минимална ширина. Колоните запълват свободното място или се превъртат хоризонтално. Отнася се само за персонализирания изглед.';

  @override
  String get settingsAppearanceLanguage => 'Облик и език';

  @override
  String get settingsAppearanceDetails => 'Цветове и контури';

  @override
  String get monthNoEvents => 'Няма събития за този ден';

  @override
  String get settingsOverview => 'Общ преглед';

  @override
  String get settingsThemeTarget => 'Тема за';

  @override
  String get settingsColorMode => 'Цветови режим';

  @override
  String get settingsNotificationPreferences => 'Настройки за напомняния';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Стандартни напомняния, разрешения и надеждност';

  @override
  String get settingsFeaturesSummary => 'Работни пространства и навигация';

  @override
  String get settingsPrivacySummary =>
      'Политика за поверителност и изчистване на локални данни';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count учебни часа',
      one: '1 учебен час',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Час';

  @override
  String get periodTimesDurationColumn => 'Продължителност';

  @override
  String get periodTimesGapColumn => 'Почивка';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes мин';
  }

  @override
  String get periodTimesSavePending => 'Изчакване за запазване…';

  @override
  String get periodTimesSaveFailed => 'Незапазено · Неуспешно запазване';

  @override
  String get periodTimesInvalidStatus =>
      'Незапазено · Поправете отбелязаните часове';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked не може да потвърди дали последното записване е отменено. Записването е спряно, а копията за възстановяване са запазени. Проверете хранилището и опитайте да заредите отново.';

  @override
  String get settingsPanelDisplayMode => 'Показване на панелите';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Общо за учебни разписания и календари';

  @override
  String get settingsPanelDisplayOverlay => 'Наслагване';

  @override
  String get settingsPanelDisplaySideBySide => 'Един до друг';

  @override
  String get settingsPanelDisplayAutomatic => 'Автоматично';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Наслагва панела вдясно, без да променя ширината на календара.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Предпочита един до друг; наслагва само ако календарът стане твърде тесен.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Показва един до друг, ако календарът остава четим, иначе наслагва.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Изключването на „Настройки“ или „Работно пространство“ в лентата ги премества в „Още“, вместо да ги премахва. „Още“ не може да се скрие, докато съдържа основни действия. Смяната на работното пространство се показва само когато долната навигация е скрита и са включени няколко работни пространства.';

  @override
  String get reminderEnded => 'Приключило';

  @override
  String get reminderAutoCloseHint =>
      'Затваря се след 10 секунди. Използвайте панела, за да остане отворен.';

  @override
  String get showReminderIndependently => 'Отваряне отделно';

  @override
  String get categoryManagerTitle => 'Управление на категориите';

  @override
  String get categoryHidden => 'Скрита';

  @override
  String get categoryShowOnCalendar => 'Показване в календара';

  @override
  String get categoryHideOnCalendar => 'Скриване от календара';

  @override
  String get categoryEditColor => 'Промяна на цвета на категорията';

  @override
  String get categoryThemePalette => 'Палитра на темата';

  @override
  String get categoryCustomColor => 'По избор';

  @override
  String get colorHexInvalid =>
      'Въведете шестцифрен шестнадесетичен код на цвят.';

  @override
  String categoryColorSlot(int number) {
    return 'Цвят на темата $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Актуализациите в магазина може да се появят по-късно. Проверете наличността на страницата в магазина.';

  @override
  String get storePrereleaseNotice =>
      'Получаването на известия за предварителни версии не ви включва в тестова програма на магазина.';

  @override
  String get updateFoundTitle => 'Налична е нова версия';

  @override
  String get updateNoNotes => 'Не са предоставени бележки за версията.';

  @override
  String get updateLater => 'По-късно';

  @override
  String get updateRetry => 'Повторен опит';

  @override
  String get updatePrerelease => 'Предварителна версия';

  @override
  String get updateNetworkFailure =>
      'Актуализациите не могат да бъдат проверени. Проверете връзката и опитайте отново.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Няма по-нова версия (текуща: $version)';
  }

  @override
  String get backupRestoreInProgressTitle =>
      'Възстановяване на резервно копие…';

  @override
  String get backupRestoreInProgressMessage =>
      'Данните и настройките могат да се променят след края на възстановяването. Все още можете да ги преглеждате.';
}
