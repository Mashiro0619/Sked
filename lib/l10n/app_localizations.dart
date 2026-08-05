import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bg.dart';
import 'app_localizations_cs.dart';
import 'app_localizations_da.dart';
import 'app_localizations_de.dart';
import 'app_localizations_el.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_et.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sl.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_th.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bg'),
    Locale('cs'),
    Locale('da'),
    Locale('de'),
    Locale('el'),
    Locale('en'),
    Locale('es'),
    Locale('et'),
    Locale('fi'),
    Locale('fr'),
    Locale('hi'),
    Locale('hu'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('ro'),
    Locale('ru'),
    Locale('sl'),
    Locale('sv'),
    Locale('th'),
    Locale('vi'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sked'**
  String get appTitle;

  /// No description provided for @weekLabel.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String weekLabel(int week);

  /// No description provided for @addCourse.
  ///
  /// In en, this message translates to:
  /// **'Add course'**
  String get addCourse;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @multiTimetableSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch timetables'**
  String get multiTimetableSwitch;

  /// No description provided for @currentTimetableWeeks.
  ///
  /// In en, this message translates to:
  /// **'Current timetable · {weeks} weeks'**
  String currentTimetableWeeks(int weeks);

  /// No description provided for @tapToSwitchWeeks.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch · {weeks} weeks'**
  String tapToSwitchWeeks(int weeks);

  /// No description provided for @editTimetable.
  ///
  /// In en, this message translates to:
  /// **'Edit timetable'**
  String get editTimetable;

  /// No description provided for @createTimetable.
  ///
  /// In en, this message translates to:
  /// **'New timetable'**
  String get createTimetable;

  /// No description provided for @jumpToWeek.
  ///
  /// In en, this message translates to:
  /// **'Jump to week'**
  String get jumpToWeek;

  /// No description provided for @timetable.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get timetable;

  /// No description provided for @timetableName.
  ///
  /// In en, this message translates to:
  /// **'Timetable name'**
  String get timetableName;

  /// No description provided for @totalWeeks.
  ///
  /// In en, this message translates to:
  /// **'Total weeks'**
  String get totalWeeks;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @deleteTimetableTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete timetable'**
  String get deleteTimetableTitle;

  /// No description provided for @deleteTimetableMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteTimetableMessage(Object name);

  /// No description provided for @noTimetableTitle.
  ///
  /// In en, this message translates to:
  /// **'No timetable yet'**
  String get noTimetableTitle;

  /// No description provided for @noTimetableMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a timetable or import one from a JSON file.'**
  String get noTimetableMessage;

  /// No description provided for @importTimetable.
  ///
  /// In en, this message translates to:
  /// **'Import timetable'**
  String get importTimetable;

  /// No description provided for @courseName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get courseName;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @dayOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dayOfWeek;

  /// No description provided for @semesterWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get semesterWeeks;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

  /// No description provided for @linkedPeriods.
  ///
  /// In en, this message translates to:
  /// **'Linked periods'**
  String get linkedPeriods;

  /// No description provided for @linkedPeriodsUnmatched.
  ///
  /// In en, this message translates to:
  /// **'No periods matched for the current time. Tap to choose manually.'**
  String get linkedPeriodsUnmatched;

  /// No description provided for @periodRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Period {start}-{end}'**
  String periodRangeLabel(int start, int end);

  /// No description provided for @teacherName.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacherName;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @remarks.
  ///
  /// In en, this message translates to:
  /// **'Remarks'**
  String get remarks;

  /// No description provided for @customFields.
  ///
  /// In en, this message translates to:
  /// **'Custom fields'**
  String get customFields;

  /// No description provided for @customFieldsHint.
  ///
  /// In en, this message translates to:
  /// **'One per line, format: key:value'**
  String get customFieldsHint;

  /// No description provided for @selectDayOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Choose day'**
  String get selectDayOfWeek;

  /// No description provided for @selectSemesterWeeks.
  ///
  /// In en, this message translates to:
  /// **'Choose weeks'**
  String get selectSemesterWeeks;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @selectLinkedPeriods.
  ///
  /// In en, this message translates to:
  /// **'Choose linked periods'**
  String get selectLinkedPeriods;

  /// No description provided for @addCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add course'**
  String get addCourseTitle;

  /// No description provided for @editCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit course'**
  String get editCourseTitle;

  /// No description provided for @editCourseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit course'**
  String get editCourseTooltip;

  /// No description provided for @place.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get place;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @notFilled.
  ///
  /// In en, this message translates to:
  /// **'Not filled'**
  String get notFilled;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @conflictCourses.
  ///
  /// In en, this message translates to:
  /// **'Conflicting courses'**
  String get conflictCourses;

  /// No description provided for @locationNotFilled.
  ///
  /// In en, this message translates to:
  /// **'Location not filled'**
  String get locationNotFilled;

  /// No description provided for @setAsDisplayed.
  ///
  /// In en, this message translates to:
  /// **'Set as displayed'**
  String get setAsDisplayed;

  /// No description provided for @editThisCourse.
  ///
  /// In en, this message translates to:
  /// **'Edit this course'**
  String get editThisCourse;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionTimetable.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get settingsSectionTimetable;

  /// No description provided for @settingsSectionGeneralSchedule.
  ///
  /// In en, this message translates to:
  /// **'General schedule'**
  String get settingsSectionGeneralSchedule;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsSectionApp;

  /// No description provided for @noTimetableSettings.
  ///
  /// In en, this message translates to:
  /// **'No timetable is currently available for settings.'**
  String get noTimetableSettings;

  /// No description provided for @semesterStartDate.
  ///
  /// In en, this message translates to:
  /// **'Semester start date'**
  String get semesterStartDate;

  /// No description provided for @periodTimeSets.
  ///
  /// In en, this message translates to:
  /// **'Period time set'**
  String get periodTimeSets;

  /// No description provided for @noPeriodTimeAvailable.
  ///
  /// In en, this message translates to:
  /// **'No available period time set'**
  String get noPeriodTimeAvailable;

  /// No description provided for @periodTimeSetSummary.
  ///
  /// In en, this message translates to:
  /// **'{name} · {count} periods'**
  String periodTimeSetSummary(Object name, int count);

  /// No description provided for @coursePopupDismissSetting.
  ///
  /// In en, this message translates to:
  /// **'Allow outside tap to close course popup'**
  String get coursePopupDismissSetting;

  /// No description provided for @coursePopupDismissSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Turning this off also disables swipe-down dismissal.'**
  String get coursePopupDismissSettingHint;

  /// No description provided for @preserveTimetableGaps.
  ///
  /// In en, this message translates to:
  /// **'Preserve timetable gaps'**
  String get preserveTimetableGaps;

  /// No description provided for @preserveTimetableGapsHint.
  ///
  /// In en, this message translates to:
  /// **'When off, lunch and break gaps are collapsed so later classes move upward.'**
  String get preserveTimetableGapsHint;

  /// No description provided for @showPastEndedCourses.
  ///
  /// In en, this message translates to:
  /// **'Show past-ended courses'**
  String get showPastEndedCourses;

  /// No description provided for @showPastEndedCoursesHint.
  ///
  /// In en, this message translates to:
  /// **'Show courses that have already finished by the real current week with a lighter gray style.'**
  String get showPastEndedCoursesHint;

  /// No description provided for @showFutureCourses.
  ///
  /// In en, this message translates to:
  /// **'Show future courses'**
  String get showFutureCourses;

  /// No description provided for @showFutureCoursesHint.
  ///
  /// In en, this message translates to:
  /// **'Show courses that are not active this week but will appear in later weeks with a gray style.'**
  String get showFutureCoursesHint;

  /// No description provided for @timetableDisplaySettings.
  ///
  /// In en, this message translates to:
  /// **'Timetable display and interaction'**
  String get timetableDisplaySettings;

  /// No description provided for @timetableDisplaySettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Popup dismissal, gaps, gray courses, and grid lines'**
  String get timetableDisplaySettingsDesc;

  /// No description provided for @showTimetableGridLines.
  ///
  /// In en, this message translates to:
  /// **'Show timetable grid lines'**
  String get showTimetableGridLines;

  /// No description provided for @showTimetableGridLinesHint.
  ///
  /// In en, this message translates to:
  /// **'Control whether horizontal and vertical grid lines are visible in the timetable.'**
  String get showTimetableGridLinesHint;

  /// No description provided for @liveCourseOutlineColor.
  ///
  /// In en, this message translates to:
  /// **'Course outline color'**
  String get liveCourseOutlineColor;

  /// No description provided for @liveCourseOutlineColorHint.
  ///
  /// In en, this message translates to:
  /// **'Choose whether outlines target the current/next course or all displayed courses on the current page.'**
  String get liveCourseOutlineColorHint;

  /// No description provided for @liveCourseOutlineSettings.
  ///
  /// In en, this message translates to:
  /// **'Course outline'**
  String get liveCourseOutlineSettings;

  /// No description provided for @liveCourseOutlineSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Configure whether the outline is enabled, what it targets, whether it follows the theme color, and the effective outline color.'**
  String get liveCourseOutlineSettingsHint;

  /// No description provided for @liveCourseOutlineEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable outline'**
  String get liveCourseOutlineEnabled;

  /// No description provided for @liveCourseOutlineFollowTheme.
  ///
  /// In en, this message translates to:
  /// **'Follow theme color'**
  String get liveCourseOutlineFollowTheme;

  /// No description provided for @liveCourseOutlineTarget.
  ///
  /// In en, this message translates to:
  /// **'Outline target'**
  String get liveCourseOutlineTarget;

  /// No description provided for @liveCourseOutlineTargetCurrentOrNext.
  ///
  /// In en, this message translates to:
  /// **'Current/next course'**
  String get liveCourseOutlineTargetCurrentOrNext;

  /// No description provided for @liveCourseOutlineTargetAllDisplayed.
  ///
  /// In en, this message translates to:
  /// **'All displayed courses'**
  String get liveCourseOutlineTargetAllDisplayed;

  /// No description provided for @liveCourseOutlineEffectiveColor.
  ///
  /// In en, this message translates to:
  /// **'Effective color'**
  String get liveCourseOutlineEffectiveColor;

  /// No description provided for @liveCourseOutlineCustomColor.
  ///
  /// In en, this message translates to:
  /// **'Custom outline color'**
  String get liveCourseOutlineCustomColor;

  /// No description provided for @liveCourseOutlineWidth.
  ///
  /// In en, this message translates to:
  /// **'Outline width'**
  String get liveCourseOutlineWidth;

  /// No description provided for @outlineWidthUnit.
  ///
  /// In en, this message translates to:
  /// **'px'**
  String get outlineWidthUnit;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languagePageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose one of the languages that is truly available in the app.'**
  String get languagePageDescription;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @githubRepositoryUrl.
  ///
  /// In en, this message translates to:
  /// **'github.com/Mashiro0619/Sked'**
  String get githubRepositoryUrl;

  /// No description provided for @apiResponseTitle.
  ///
  /// In en, this message translates to:
  /// **'API response'**
  String get apiResponseTitle;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeFollowSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get themeColor;

  /// No description provided for @themeColorModeSingle.
  ///
  /// In en, this message translates to:
  /// **'Single theme color'**
  String get themeColorModeSingle;

  /// No description provided for @themeColorModeColorful.
  ///
  /// In en, this message translates to:
  /// **'Colorful'**
  String get themeColorModeColorful;

  /// No description provided for @themeColorUiColors.
  ///
  /// In en, this message translates to:
  /// **'UI colors'**
  String get themeColorUiColors;

  /// No description provided for @themeColorCourseColors.
  ///
  /// In en, this message translates to:
  /// **'Course colors'**
  String get themeColorCourseColors;

  /// No description provided for @themeColorPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get themeColorPrimary;

  /// No description provided for @themeColorSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get themeColorSecondary;

  /// No description provided for @themeColorTertiary.
  ///
  /// In en, this message translates to:
  /// **'Tertiary'**
  String get themeColorTertiary;

  /// No description provided for @themeColorCourseText.
  ///
  /// In en, this message translates to:
  /// **'Course text'**
  String get themeColorCourseText;

  /// No description provided for @themeColorCourseTextAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeColorCourseTextAuto;

  /// No description provided for @themeColorCourseTextCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get themeColorCourseTextCustom;

  /// No description provided for @themeColorCourseColorsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Course colors will be generated after importing a timetable.'**
  String get themeColorCourseColorsEmpty;

  /// No description provided for @themeCustomColor.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get themeCustomColor;

  /// No description provided for @themeApplyCustomColor.
  ///
  /// In en, this message translates to:
  /// **'Apply color'**
  String get themeApplyCustomColor;

  /// No description provided for @themeApplySettings.
  ///
  /// In en, this message translates to:
  /// **'Apply settings'**
  String get themeApplySettings;

  /// No description provided for @dataImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import and export data'**
  String get dataImportExport;

  /// No description provided for @dataImportExportDesc.
  ///
  /// In en, this message translates to:
  /// **'Import full data or single timetables, or export current/all timetables.'**
  String get dataImportExportDesc;

  /// No description provided for @appBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'App backup and restore'**
  String get appBackupTitle;

  /// No description provided for @appBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up or restore timetables, schedules, settings, and school sites. API keys are not included.'**
  String get appBackupSubtitle;

  /// No description provided for @appBackupSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A full restore replaces current app data. Custom parser API keys live in secure storage and are not written to backup files.'**
  String get appBackupSheetSubtitle;

  /// No description provided for @restoreBackupFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from JSON file'**
  String get restoreBackupFileTitle;

  /// No description provided for @restoreBackupFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a full Sked backup file. You will confirm before restoring.'**
  String get restoreBackupFileSubtitle;

  /// No description provided for @restoreBackupTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste backup JSON'**
  String get restoreBackupTextTitle;

  /// No description provided for @restoreBackupTextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a full backup and restore current app data.'**
  String get restoreBackupTextSubtitle;

  /// No description provided for @shareBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Share backup file'**
  String get shareBackupTitle;

  /// No description provided for @shareBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export full app data as JSON. API keys are excluded.'**
  String get shareBackupSubtitle;

  /// No description provided for @saveBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Save backup file'**
  String get saveBackupTitle;

  /// No description provided for @saveBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a full app backup to a local file.'**
  String get saveBackupSubtitle;

  /// No description provided for @copyBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy backup text'**
  String get copyBackupTitle;

  /// No description provided for @copyBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the full backup JSON so you can copy or store it temporarily.'**
  String get copyBackupSubtitle;

  /// No description provided for @restoreBackupConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore full backup?'**
  String get restoreBackupConfirmTitle;

  /// No description provided for @restoreBackupConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This replaces all current timetables, general schedules, settings, and school sites. API keys are not imported from backups; re-enter the key before parsing timetables again.'**
  String get restoreBackupConfirmMessage;

  /// No description provided for @restoreBackupConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreBackupConfirmAction;

  /// No description provided for @restoreBackupSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Full app backup restored. Parser API keys must be re-entered.'**
  String get restoreBackupSuccessMessage;

  /// No description provided for @restoreBackupFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Please check the backup content and try again.'**
  String get restoreBackupFailureMessage;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @openSourceLicensesDesc.
  ///
  /// In en, this message translates to:
  /// **'View licenses for Flutter dependencies and bundled app icon assets.'**
  String get openSourceLicensesDesc;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkForUpdatesDesc.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get checkForUpdatesDesc;

  /// No description provided for @alreadyLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Already on the latest version ({version})'**
  String alreadyLatestVersion(Object version);

  /// No description provided for @currentVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get currentVersionLabel;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get newVersionAvailable;

  /// No description provided for @latestVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest version'**
  String get latestVersionLabel;

  /// No description provided for @updateContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Update details'**
  String get updateContentLabel;

  /// No description provided for @officialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official website'**
  String get officialWebsite;

  /// No description provided for @googlePlay.
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get googlePlay;

  /// No description provided for @cloudDrive.
  ///
  /// In en, this message translates to:
  /// **'Cloud drive'**
  String get cloudDrive;

  /// No description provided for @ignoreThisVersion.
  ///
  /// In en, this message translates to:
  /// **'Ignore this version'**
  String get ignoreThisVersion;

  /// No description provided for @openUpdatesFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the update link'**
  String get openUpdatesFailed;

  /// No description provided for @updateCheckFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get updateCheckFailedTitle;

  /// No description provided for @updateCheckFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.'**
  String get updateCheckFailedMessage;

  /// No description provided for @githubRepository.
  ///
  /// In en, this message translates to:
  /// **'GitHub repository'**
  String get githubRepository;

  /// No description provided for @openGithubFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the GitHub repository link'**
  String get openGithubFailed;

  /// No description provided for @selectPeriodTimeSet.
  ///
  /// In en, this message translates to:
  /// **'Choose period time set'**
  String get selectPeriodTimeSet;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newItem;

  /// No description provided for @editPeriodTimeSet.
  ///
  /// In en, this message translates to:
  /// **'Edit period time set'**
  String get editPeriodTimeSet;

  /// No description provided for @importTimetableFiles.
  ///
  /// In en, this message translates to:
  /// **'Import timetable'**
  String get importTimetableFiles;

  /// No description provided for @importTimetableFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Supports one or multiple timetable files.'**
  String get importTimetableFilesDesc;

  /// No description provided for @importTimetableText.
  ///
  /// In en, this message translates to:
  /// **'Import timetable from JSON text'**
  String get importTimetableText;

  /// No description provided for @importTimetableTextDesc.
  ///
  /// In en, this message translates to:
  /// **'Paste timetable JSON content and import it.'**
  String get importTimetableTextDesc;

  /// No description provided for @shareTimetableFiles.
  ///
  /// In en, this message translates to:
  /// **'Share timetable files'**
  String get shareTimetableFiles;

  /// No description provided for @shareTimetableFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more timetables first.'**
  String get shareTimetableFilesDesc;

  /// No description provided for @saveTimetableFiles.
  ///
  /// In en, this message translates to:
  /// **'Save timetable files'**
  String get saveTimetableFiles;

  /// No description provided for @saveTimetableFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more timetables first.'**
  String get saveTimetableFilesDesc;

  /// No description provided for @exportTimetableText.
  ///
  /// In en, this message translates to:
  /// **'Export timetable as JSON text'**
  String get exportTimetableText;

  /// No description provided for @exportTimetableTextDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more timetables, then copy the JSON content.'**
  String get exportTimetableTextDesc;

  /// No description provided for @jsonContent.
  ///
  /// In en, this message translates to:
  /// **'JSON content'**
  String get jsonContent;

  /// No description provided for @pasteJsonContentHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the JSON content to import.'**
  String get pasteJsonContentHint;

  /// No description provided for @jsonContentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON content first.'**
  String get jsonContentEmpty;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyText;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @selectTimetablesToExport.
  ///
  /// In en, this message translates to:
  /// **'Choose timetables to export'**
  String get selectTimetablesToExport;

  /// No description provided for @selectTimetablesToImport.
  ///
  /// In en, this message translates to:
  /// **'Choose timetables to import'**
  String get selectTimetablesToImport;

  /// No description provided for @timetableCourseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} courses'**
  String timetableCourseCount(int count);

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @importTimetableDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import timetable'**
  String get importTimetableDialogTitle;

  /// No description provided for @chooseImportMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose how to import.'**
  String get chooseImportMethod;

  /// No description provided for @importAsNewTimetable.
  ///
  /// In en, this message translates to:
  /// **'Import as new timetable'**
  String get importAsNewTimetable;

  /// No description provided for @replaceCurrentTimetable.
  ///
  /// In en, this message translates to:
  /// **'Replace current timetable'**
  String get replaceCurrentTimetable;

  /// No description provided for @importPeriodTimeSetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import period time sets'**
  String get importPeriodTimeSetDialogTitle;

  /// No description provided for @importPeriodTimeSetDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This file contains bundled period time sets. Do you want to import and associate them?'**
  String get importPeriodTimeSetDialogBody;

  /// No description provided for @importBundledPeriodTimeSets.
  ///
  /// In en, this message translates to:
  /// **'Import and associate'**
  String get importBundledPeriodTimeSets;

  /// No description provided for @discardBundledPeriodTimeSets.
  ///
  /// In en, this message translates to:
  /// **'Discard bundled sets'**
  String get discardBundledPeriodTimeSets;

  /// No description provided for @importDiscardPeriodTimeSetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No existing period time set is available, so bundled period time sets cannot be discarded.'**
  String get importDiscardPeriodTimeSetUnavailable;

  /// No description provided for @savedToPath.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String savedToPath(Object path);

  /// No description provided for @saveCancelled.
  ///
  /// In en, this message translates to:
  /// **'Save cancelled'**
  String get saveCancelled;

  /// No description provided for @fileSaveRestrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'File saving restricted'**
  String get fileSaveRestrictedTitle;

  /// No description provided for @fileSaveRestrictedRetryMessage.
  ///
  /// In en, this message translates to:
  /// **'The system could not save the file. You can retry or use sharing instead.'**
  String get fileSaveRestrictedRetryMessage;

  /// No description provided for @retrySave.
  ///
  /// In en, this message translates to:
  /// **'Retry save'**
  String get retrySave;

  /// No description provided for @fileSaveRestrictedSettingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Enable file access in system settings, then return and try exporting again.'**
  String get fileSaveRestrictedSettingsMessage;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @browserDownloadRestrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser download restricted'**
  String get browserDownloadRestrictedTitle;

  /// No description provided for @browserDownloadRestrictedMessage.
  ///
  /// In en, this message translates to:
  /// **'This browser does not support directly saving to a local file. Check browser download permissions or use file sharing instead.'**
  String get browserDownloadRestrictedMessage;

  /// No description provided for @switchToShare.
  ///
  /// In en, this message translates to:
  /// **'Use sharing instead'**
  String get switchToShare;

  /// No description provided for @fileSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'File save failed'**
  String get fileSaveFailedTitle;

  /// No description provided for @fileSaveFailedWindowsMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to write to the current path. The target folder may be protected, the file may be in use, or the path may be unwritable.'**
  String get fileSaveFailedWindowsMessage;

  /// No description provided for @fileSaveFailedGenericMessage.
  ///
  /// In en, this message translates to:
  /// **'The system could not save the file. You can retry, check system settings, or use file sharing instead.'**
  String get fileSaveFailedGenericMessage;

  /// No description provided for @retryLater.
  ///
  /// In en, this message translates to:
  /// **'Try again later'**
  String get retryLater;

  /// No description provided for @exportSwitchedToShare.
  ///
  /// In en, this message translates to:
  /// **'Switched to file sharing for export'**
  String get exportSwitchedToShare;

  /// No description provided for @saveFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Please try again later.'**
  String get saveFailedRetry;

  /// No description provided for @appInstanceBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sked is already open'**
  String get appInstanceBlockedTitle;

  /// No description provided for @appInstanceBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Another Sked window or browser tab is using your local data. Close it, then retry.'**
  String get appInstanceBlockedMessage;

  /// No description provided for @appInstanceLeaseFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Local data is unavailable'**
  String get appInstanceLeaseFailedTitle;

  /// No description provided for @appInstanceLeaseFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sked could not verify exclusive access to local data. Your data was not opened or changed. Check storage access, then retry.'**
  String get appInstanceLeaseFailedMessage;

  /// No description provided for @savingChanges.
  ///
  /// In en, this message translates to:
  /// **'Saving changes...'**
  String get savingChanges;

  /// No description provided for @showApiKey.
  ///
  /// In en, this message translates to:
  /// **'Show API key'**
  String get showApiKey;

  /// No description provided for @hideApiKey.
  ///
  /// In en, this message translates to:
  /// **'Hide API key'**
  String get hideApiKey;

  /// No description provided for @importFailedCheckContent.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Please check the file content.'**
  String get importFailedCheckContent;

  /// No description provided for @noImportableTimetables.
  ///
  /// In en, this message translates to:
  /// **'No usable timetables were found in the imported file.'**
  String get noImportableTimetables;

  /// No description provided for @importedTimetablesCount.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} timetables'**
  String importedTimetablesCount(int count);

  /// No description provided for @periodTimesTitle.
  ///
  /// In en, this message translates to:
  /// **'Period times'**
  String get periodTimesTitle;

  /// No description provided for @importExport.
  ///
  /// In en, this message translates to:
  /// **'Import and export'**
  String get importExport;

  /// No description provided for @importPeriodTemplate.
  ///
  /// In en, this message translates to:
  /// **'Import period template'**
  String get importPeriodTemplate;

  /// No description provided for @importPeriodTemplateText.
  ///
  /// In en, this message translates to:
  /// **'Import period template from text'**
  String get importPeriodTemplateText;

  /// No description provided for @sharePeriodTemplate.
  ///
  /// In en, this message translates to:
  /// **'Share period template'**
  String get sharePeriodTemplate;

  /// No description provided for @saveTemplateToFile.
  ///
  /// In en, this message translates to:
  /// **'Save template to file'**
  String get saveTemplateToFile;

  /// No description provided for @exportPeriodTemplateText.
  ///
  /// In en, this message translates to:
  /// **'Export period template as text'**
  String get exportPeriodTemplateText;

  /// No description provided for @deletePeriodTimeSet.
  ///
  /// In en, this message translates to:
  /// **'Delete period time set'**
  String get deletePeriodTimeSet;

  /// No description provided for @periodTimeSetName.
  ///
  /// In en, this message translates to:
  /// **'Period time set name'**
  String get periodTimeSetName;

  /// No description provided for @addOnePeriod.
  ///
  /// In en, this message translates to:
  /// **'Add period'**
  String get addOnePeriod;

  /// No description provided for @periodNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Period {index}'**
  String periodNumberLabel(int index);

  /// No description provided for @deleteThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'Delete this period'**
  String get deleteThisPeriod;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration {minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @gapFromPrevious.
  ///
  /// In en, this message translates to:
  /// **'Gap from previous {minutes} min'**
  String gapFromPrevious(int minutes);

  /// No description provided for @endTimeMustBeLater.
  ///
  /// In en, this message translates to:
  /// **'End time must be later than start time'**
  String get endTimeMustBeLater;

  /// No description provided for @periodOverlapPrevious.
  ///
  /// In en, this message translates to:
  /// **'This period overlaps the previous one'**
  String get periodOverlapPrevious;

  /// No description provided for @periodTimesSaved.
  ///
  /// In en, this message translates to:
  /// **'Period times saved'**
  String get periodTimesSaved;

  /// No description provided for @deletePeriodTimeSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete period time set'**
  String get deletePeriodTimeSetTitle;

  /// No description provided for @deletePeriodTimeSetMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deletePeriodTimeSetMessage(Object name);

  /// No description provided for @currentPeriodTimeSet.
  ///
  /// In en, this message translates to:
  /// **'current period time set'**
  String get currentPeriodTimeSet;

  /// No description provided for @importedPeriodTimesCount.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} period times'**
  String importedPeriodTimesCount(int count);

  /// No description provided for @periodFilePermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'File permission needed'**
  String get periodFilePermissionTitle;

  /// No description provided for @androidFilePermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Android export requires file access permission. Grant permission to continue saving.'**
  String get androidFilePermissionMessage;

  /// No description provided for @reauthorize.
  ///
  /// In en, this message translates to:
  /// **'Authorize again'**
  String get reauthorize;

  /// No description provided for @permissionPermanentlyDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission permanently denied'**
  String get permissionPermanentlyDeniedTitle;

  /// No description provided for @permissionSettingsExportMessage.
  ///
  /// In en, this message translates to:
  /// **'Enable file access in system settings, then return and try exporting again.'**
  String get permissionSettingsExportMessage;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyEntryDesc.
  ///
  /// In en, this message translates to:
  /// **'Learn how the app handles local storage, school-site configuration, file import/export, timetable text / HTML parsing, and external links.'**
  String get privacyPolicyEntryDesc;

  /// No description provided for @privacyPolicyAcceptedVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Accepted version: {version}'**
  String privacyPolicyAcceptedVersionLabel(Object version);

  /// No description provided for @privacyPolicyIntro.
  ///
  /// In en, this message translates to:
  /// **'Sked is a local-first timetable tool. Timetables, general schedules, period-time sets, and school-site configuration are stored only on your device or in your browser, and are never automatically uploaded. The app only processes data when you explicitly trigger actions such as import, timetable text / HTML parsing, school webpage import, sharing, or opening external links. The full privacy policy is available online.'**
  String get privacyPolicyIntro;

  /// No description provided for @privacyPolicyLocalStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Local storage'**
  String get privacyPolicyLocalStorageTitle;

  /// No description provided for @privacyPolicyLocalStorageBody.
  ///
  /// In en, this message translates to:
  /// **'Timetable data, general schedules, related settings, and full app backup content are stored locally on your device or in browser storage. Editable school-site configuration is stored separately in Sked_school_sites.json. Custom timetable parser settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.'**
  String get privacyPolicyLocalStorageBody;

  /// No description provided for @privacyPolicyImportExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import and export'**
  String get privacyPolicyImportExportTitle;

  /// No description provided for @privacyPolicyImportExportBody.
  ///
  /// In en, this message translates to:
  /// **'The app reads or writes timetable JSON files, timetable JSON text, general schedule JSON / ICS files, full app backup JSON files, school-site JSON files, and period-template files only when you explicitly choose a file, paste JSON, or start an export action. Importing these files and JSON text is a local operation unless you also choose timetable text / HTML parsing or school webpage import. Fetching a custom model list is also an explicit network action and only contacts the custom endpoint you configured.'**
  String get privacyPolicyImportExportBody;

  /// No description provided for @privacyPolicySharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get privacyPolicySharingTitle;

  /// No description provided for @privacyPolicySharingBody.
  ///
  /// In en, this message translates to:
  /// **'When you explicitly use sharing, the app passes the exported file to the system share sheet or to the target app you choose. How that file is handled afterward depends on the target app or service you selected.'**
  String get privacyPolicySharingBody;

  /// No description provided for @privacyPolicyExternalLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'External links'**
  String get privacyPolicyExternalLinksTitle;

  /// No description provided for @privacyPolicyExternalLinksBody.
  ///
  /// In en, this message translates to:
  /// **'When you open external links such as the GitHub repository, the app hands the action off to your browser or another external application. Data handling after that point is governed by the third party you open.'**
  String get privacyPolicyExternalLinksBody;

  /// No description provided for @privacyPolicyNoCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'What the app does not collect'**
  String get privacyPolicyNoCollectionTitle;

  /// No description provided for @privacyPolicyNoCollectionBody.
  ///
  /// In en, this message translates to:
  /// **'The app does not require a Sked account and does not enable analytics, advertising identifiers, or cloud backup. It also does not provide a dedicated field for collecting school account passwords. If you sign in to a school website inside the app, that interaction happens on the school page you opened.'**
  String get privacyPolicyNoCollectionBody;

  /// No description provided for @privacyPolicyFutureFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Timetable text / HTML parsing'**
  String get privacyPolicyFutureFeatureTitle;

  /// No description provided for @privacyPolicyFutureFeatureBody.
  ///
  /// In en, this message translates to:
  /// **'When you use school webpage import or parse pasted timetable text / HTML, the app first prepares and cleans the content locally, then sends the submitted timetable text, page text or HTML content, optional page title and URL, the current app language, and parser prompt content to the OpenAI-compatible endpoint you configured. Fetching the model list also requests that same configured endpoint. Sked does not provide a built-in parser endpoint and does not send parsing requests to a developer-controlled timetable parser backend. The custom endpoint and any upstream services may store, forward, limit, delete, or otherwise process data according to the rules of the service provider you choose. If you use an http:// Base URL, only use it on trusted devices, trusted networks, and trusted endpoint services, because content and API keys may not be protected by transport encryption.'**
  String get privacyPolicyFutureFeatureBody;

  /// No description provided for @privacyPolicyUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Policy updates'**
  String get privacyPolicyUpdatesTitle;

  /// No description provided for @privacyPolicyUpdatesBody.
  ///
  /// In en, this message translates to:
  /// **'The current privacy policy version is {version}. If a later version changes how data is handled, the app may ask you to read and agree to the updated policy again.'**
  String privacyPolicyUpdatesBody(Object version);

  /// No description provided for @privacyGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the privacy policy before using the app'**
  String get privacyGateTitle;

  /// No description provided for @privacyGateSummaryStorage.
  ///
  /// In en, this message translates to:
  /// **'Timetables, general schedules, period-time sets, and school-site configuration are only stored locally and are not automatically uploaded to a developer server.'**
  String get privacyGateSummaryStorage;

  /// No description provided for @privacyGateSummaryImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import, export, full backups, and sharing only happen when you explicitly start them; full app backups exclude custom API keys, and timetable text / HTML parsing only sends submitted content to your configured parser endpoint.'**
  String get privacyGateSummaryImportExport;

  /// No description provided for @privacyGateSummaryUpdates.
  ///
  /// In en, this message translates to:
  /// **'If a later version changes how data is handled, the app may ask you to review the updated privacy policy again.'**
  String get privacyGateSummaryUpdates;

  /// No description provided for @schoolWebImportEntry.
  ///
  /// In en, this message translates to:
  /// **'Import from school webpage'**
  String get schoolWebImportEntry;

  /// No description provided for @schoolWebImportEntryDesc.
  ///
  /// In en, this message translates to:
  /// **'Import the current timetable page from the school site.'**
  String get schoolWebImportEntryDesc;

  /// No description provided for @schoolSitesManageEntry.
  ///
  /// In en, this message translates to:
  /// **'Manage school sites'**
  String get schoolSitesManageEntry;

  /// No description provided for @schoolSitesManageEntryDesc.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, and delete school login URLs, with JSON import and export.'**
  String get schoolSitesManageEntryDesc;

  /// No description provided for @schoolSitesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'School site management'**
  String get schoolSitesPageTitle;

  /// No description provided for @schoolSitesImportJson.
  ///
  /// In en, this message translates to:
  /// **'Import school JSON'**
  String get schoolSitesImportJson;

  /// No description provided for @schoolSitesShareJson.
  ///
  /// In en, this message translates to:
  /// **'Share school JSON'**
  String get schoolSitesShareJson;

  /// No description provided for @schoolSitesSaveJson.
  ///
  /// In en, this message translates to:
  /// **'Save school JSON'**
  String get schoolSitesSaveJson;

  /// No description provided for @schoolSitesSaved.
  ///
  /// In en, this message translates to:
  /// **'School sites saved'**
  String get schoolSitesSaved;

  /// No description provided for @schoolSitesImported.
  ///
  /// In en, this message translates to:
  /// **'School sites imported'**
  String get schoolSitesImported;

  /// No description provided for @schoolSitesImportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review school-site import'**
  String get schoolSitesImportPreviewTitle;

  /// No description provided for @schoolSitesImportPreviewSummary.
  ///
  /// In en, this message translates to:
  /// **'{validCount} valid sites, {invalidCount} invalid entries.'**
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount);

  /// No description provided for @schoolSitesImportEmptyPreview.
  ///
  /// In en, this message translates to:
  /// **'The file contains an empty school-site list.'**
  String get schoolSitesImportEmptyPreview;

  /// No description provided for @schoolSitesImportInvalidEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry {position} is invalid and will be skipped.'**
  String schoolSitesImportInvalidEntry(int position);

  /// No description provided for @schoolSitesImportMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get schoolSitesImportMerge;

  /// No description provided for @schoolSitesImportReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get schoolSitesImportReplace;

  /// No description provided for @schoolSitesImportReplaceConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace current school sites?'**
  String get schoolSitesImportReplaceConfirmTitle;

  /// No description provided for @schoolSitesImportReplaceConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes {currentCount} current sites and saves {importedCount} imported sites. This cannot be undone.'**
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  );

  /// No description provided for @schoolSitesRecoveryCorruptTitle.
  ///
  /// In en, this message translates to:
  /// **'School-site data needs recovery'**
  String get schoolSitesRecoveryCorruptTitle;

  /// No description provided for @schoolSitesRecoveryCorruptMessage.
  ///
  /// In en, this message translates to:
  /// **'Sked could not read the school-site file or its backup. Protected copies were created before writes were blocked.'**
  String get schoolSitesRecoveryCorruptMessage;

  /// No description provided for @schoolSitesRecoveryIoFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'School-site storage is unavailable'**
  String get schoolSitesRecoveryIoFailureTitle;

  /// No description provided for @schoolSitesRecoveryIoFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Sked cannot access school-site storage right now. Retry after checking storage access or device availability. Current site data will not be overwritten.'**
  String get schoolSitesRecoveryIoFailureMessage;

  /// No description provided for @schoolSitesRecoveryArtifactsHint.
  ///
  /// In en, this message translates to:
  /// **'Recovery files or affected storage locations are listed below. Keep any files unchanged until the site list is recovered.'**
  String get schoolSitesRecoveryArtifactsHint;

  /// No description provided for @schoolSitesRecoveryStartFreshAction.
  ///
  /// In en, this message translates to:
  /// **'Start with no school sites'**
  String get schoolSitesRecoveryStartFreshAction;

  /// No description provided for @schoolSitesRecoveryStartFreshConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with an empty school-site list?'**
  String get schoolSitesRecoveryStartFreshConfirmTitle;

  /// No description provided for @schoolSitesRecoveryStartFreshConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Protected copies will be kept, but Sked will create a new empty school-site file. Continue only if you do not want to retry recovery first.'**
  String get schoolSitesRecoveryStartFreshConfirmMessage;

  /// No description provided for @schoolSitesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No school site configuration yet.'**
  String get schoolSitesEmpty;

  /// No description provided for @schoolSitesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'School name'**
  String get schoolSitesNameLabel;

  /// No description provided for @schoolSitesLoginUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Login URL'**
  String get schoolSitesLoginUrlLabel;

  /// No description provided for @schoolSitesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add school'**
  String get schoolSitesAdd;

  /// No description provided for @schoolSitesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit school'**
  String get schoolSitesEdit;

  /// No description provided for @schoolSitesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete school'**
  String get schoolSitesDeleteTitle;

  /// No description provided for @schoolSitesDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String schoolSitesDeleteMessage(Object name);

  /// No description provided for @schoolSitesFormInvalid.
  ///
  /// In en, this message translates to:
  /// **'Fill in the school name and login URL first.'**
  String get schoolSitesFormInvalid;

  /// No description provided for @schoolSitesJsonFileName.
  ///
  /// In en, this message translates to:
  /// **'Sked_school_sites.json'**
  String get schoolSitesJsonFileName;

  /// No description provided for @schoolHtmlImportEntry.
  ///
  /// In en, this message translates to:
  /// **'Parse timetable from text / HTML'**
  String get schoolHtmlImportEntry;

  /// No description provided for @schoolHtmlImportEntryDesc.
  ///
  /// In en, this message translates to:
  /// **'Paste plain timetable text, page text, or HTML source, then import it through your custom parser endpoint.'**
  String get schoolHtmlImportEntryDesc;

  /// No description provided for @schoolHtmlImportPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Parse timetable text / HTML'**
  String get schoolHtmlImportPageTitle;

  /// No description provided for @schoolHtmlImportUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Source URL (optional)'**
  String get schoolHtmlImportUrlLabel;

  /// No description provided for @schoolHtmlImportTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Page title (optional)'**
  String get schoolHtmlImportTitleLabel;

  /// No description provided for @schoolHtmlImportHtmlLabel.
  ///
  /// In en, this message translates to:
  /// **'Text / HTML content'**
  String get schoolHtmlImportHtmlLabel;

  /// No description provided for @schoolHtmlImportHtmlHint.
  ///
  /// In en, this message translates to:
  /// **'For example, \"Monday periods 3-4 Chinese\", or paste timetable page text or HTML source.'**
  String get schoolHtmlImportHtmlHint;

  /// No description provided for @schoolHtmlImportNonHtmlHint.
  ///
  /// In en, this message translates to:
  /// **'Any content containing timetable information can be parsed and imported; plain text and HTML are both supported.'**
  String get schoolHtmlImportNonHtmlHint;

  /// No description provided for @schoolHtmlImportCompress.
  ///
  /// In en, this message translates to:
  /// **'Prepare content'**
  String get schoolHtmlImportCompress;

  /// No description provided for @schoolHtmlImportCompressed.
  ///
  /// In en, this message translates to:
  /// **'Content prepared'**
  String get schoolHtmlImportCompressed;

  /// No description provided for @schoolHtmlImportCompressFirst.
  ///
  /// In en, this message translates to:
  /// **'Prepare the content first.'**
  String get schoolHtmlImportCompressFirst;

  /// No description provided for @schoolHtmlImportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Parse and import'**
  String get schoolHtmlImportSubmit;

  /// No description provided for @schoolImportContentTruncated.
  ///
  /// In en, this message translates to:
  /// **'This page reached the safe import limit. Only the captured portion will be sent for parsing.'**
  String get schoolImportContentTruncated;

  /// No description provided for @schoolHtmlImportParsingMayTakeLong.
  ///
  /// In en, this message translates to:
  /// **'Parsing may take a while. Please wait.'**
  String get schoolHtmlImportParsingMayTakeLong;

  /// No description provided for @schoolHtmlImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'Paste timetable text or HTML content first.'**
  String get schoolHtmlImportEmpty;

  /// No description provided for @schoolHtmlImportReturnToWebPage.
  ///
  /// In en, this message translates to:
  /// **'Back to webpage'**
  String get schoolHtmlImportReturnToWebPage;

  /// No description provided for @schoolWebImportPageTitle.
  ///
  /// In en, this message translates to:
  /// **'School webpage import'**
  String get schoolWebImportPageTitle;

  /// No description provided for @schoolWebImportPreview.
  ///
  /// In en, this message translates to:
  /// **'Import preview'**
  String get schoolWebImportPreview;

  /// No description provided for @schoolWebImportCourseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} courses'**
  String schoolWebImportCourseCount(int count);

  /// No description provided for @schoolWebImportPeriodCount.
  ///
  /// In en, this message translates to:
  /// **'{count} periods'**
  String schoolWebImportPeriodCount(int count);

  /// No description provided for @schoolWebImportPageTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Page title'**
  String get schoolWebImportPageTitleLabel;

  /// No description provided for @schoolWebImportParserUsed.
  ///
  /// In en, this message translates to:
  /// **'Parser'**
  String get schoolWebImportParserUsed;

  /// No description provided for @schoolWebImportWarnings.
  ///
  /// In en, this message translates to:
  /// **'Import notes'**
  String get schoolWebImportWarnings;

  /// No description provided for @schoolWebImportOpenPageHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to the school site in-app, then navigate to the timetable page manually.'**
  String get schoolWebImportOpenPageHint;

  /// No description provided for @schoolWebImportConfigMissing.
  ///
  /// In en, this message translates to:
  /// **'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.'**
  String get schoolWebImportConfigMissing;

  /// No description provided for @schoolWebImportUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'This platform does not support embedded web login yet. Please use a platform with WebView support.'**
  String get schoolWebImportUnsupportedPlatform;

  /// No description provided for @schoolWebImportSelectSchool.
  ///
  /// In en, this message translates to:
  /// **'Choose school'**
  String get schoolWebImportSelectSchool;

  /// No description provided for @schoolWebImportNoSchools.
  ///
  /// In en, this message translates to:
  /// **'No school configuration is available. Check school_sites.json first.'**
  String get schoolWebImportNoSchools;

  /// No description provided for @schoolWebImportSchoolLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load school configuration. Check the JSON file format.'**
  String get schoolWebImportSchoolLoadFailed;

  /// No description provided for @schoolWebImportImportCurrentPage.
  ///
  /// In en, this message translates to:
  /// **'Import current page'**
  String get schoolWebImportImportCurrentPage;

  /// No description provided for @schoolWebImportGoBack.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get schoolWebImportGoBack;

  /// No description provided for @schoolWebImportLoadingPage.
  ///
  /// In en, this message translates to:
  /// **'Loading page…'**
  String get schoolWebImportLoadingPage;

  /// No description provided for @schoolWebImportParsing.
  ///
  /// In en, this message translates to:
  /// **'Parsing current page…'**
  String get schoolWebImportParsing;

  /// No description provided for @schoolWebImportLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Page load failed. Please refresh or try again later.'**
  String get schoolWebImportLoadFailed;

  /// No description provided for @schoolWebImportLoadTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Page loading timed out. Please refresh and try again.'**
  String get schoolWebImportLoadTimedOut;

  /// No description provided for @schoolWebImportUnknownOrigin.
  ///
  /// In en, this message translates to:
  /// **'Unknown site'**
  String get schoolWebImportUnknownOrigin;

  /// No description provided for @schoolWebImportCrossOriginTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue to another site?'**
  String get schoolWebImportCrossOriginTitle;

  /// No description provided for @schoolWebImportCrossOriginMessage.
  ///
  /// In en, this message translates to:
  /// **'School sign-in may need to open another site. Continue only if you trust this destination for the current import session:\n\n{origin}'**
  String schoolWebImportCrossOriginMessage(Object origin);

  /// No description provided for @schoolWebImportEmptyPage.
  ///
  /// In en, this message translates to:
  /// **'The current page content is empty and cannot be imported yet.'**
  String get schoolWebImportEmptyPage;

  /// No description provided for @schoolWebImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Web timetable imported'**
  String get schoolWebImportSuccess;

  /// No description provided for @schoolImportParserSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Timetable parser settings'**
  String get schoolImportParserSettingsTitle;

  /// No description provided for @schoolImportParserSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure your own OpenAI-compatible endpoint. HTTP and HTTPS base URLs are supported.'**
  String get schoolImportParserSettingsDesc;

  /// No description provided for @schoolImportParserSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Parser source'**
  String get schoolImportParserSourceTitle;

  /// No description provided for @schoolImportParserSourceCustomOpenAi.
  ///
  /// In en, this message translates to:
  /// **'Custom OpenAI-compatible'**
  String get schoolImportParserSourceCustomOpenAi;

  /// No description provided for @schoolImportParserSourceCustomOpenAiDesc.
  ///
  /// In en, this message translates to:
  /// **'Send timetable text, page text, or HTML content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.'**
  String get schoolImportParserSourceCustomOpenAiDesc;

  /// No description provided for @schoolImportParserCustomOpenAi.
  ///
  /// In en, this message translates to:
  /// **'Custom OpenAI-compatible parser'**
  String get schoolImportParserCustomOpenAi;

  /// No description provided for @schoolImportParserCustomPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom prompt'**
  String get schoolImportParserCustomPromptTitle;

  /// No description provided for @schoolImportParserCustomPromptDescription.
  ///
  /// In en, this message translates to:
  /// **'Edit the built-in parser prompt here. Changes only affect the custom OpenAI-compatible parser.'**
  String get schoolImportParserCustomPromptDescription;

  /// No description provided for @schoolImportParserCustomPromptHint.
  ///
  /// In en, this message translates to:
  /// **'The built-in prompt is loaded here by default. Clear it to fall back to the built-in version.'**
  String get schoolImportParserCustomPromptHint;

  /// No description provided for @schoolImportParserResetDefaultPrompt.
  ///
  /// In en, this message translates to:
  /// **'Reset default prompt'**
  String get schoolImportParserResetDefaultPrompt;

  /// No description provided for @schoolImportParserBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get schoolImportParserBaseUrl;

  /// No description provided for @schoolImportParserBaseUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Base URL must be an HTTP or HTTPS URL with a host.'**
  String get schoolImportParserBaseUrlInvalid;

  /// No description provided for @schoolImportParserApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get schoolImportParserApiKey;

  /// No description provided for @schoolImportParserModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get schoolImportParserModel;

  /// No description provided for @schoolImportParserFetchModels.
  ///
  /// In en, this message translates to:
  /// **'Fetch model list'**
  String get schoolImportParserFetchModels;

  /// No description provided for @schoolImportParserFetchingModels.
  ///
  /// In en, this message translates to:
  /// **'Fetching models...'**
  String get schoolImportParserFetchingModels;

  /// No description provided for @schoolImportParserNoModelsFound.
  ///
  /// In en, this message translates to:
  /// **'No models were returned by the endpoint.'**
  String get schoolImportParserNoModelsFound;

  /// No description provided for @schoolImportParserFetchModelsFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch models. Check the endpoint and try again.'**
  String get schoolImportParserFetchModelsFailed;

  /// No description provided for @schoolImportParserModelsFetched.
  ///
  /// In en, this message translates to:
  /// **'Fetched {count} models'**
  String schoolImportParserModelsFetched(int count);

  /// No description provided for @schoolImportParserPlaintextWarning.
  ///
  /// In en, this message translates to:
  /// **'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.'**
  String get schoolImportParserPlaintextWarning;

  /// No description provided for @schoolImportHttpConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Use an unencrypted HTTP endpoint?'**
  String get schoolImportHttpConfirmationTitle;

  /// No description provided for @schoolImportHttpConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'The API key and timetable content may be read or changed in transit. Continue only if you trust this device, network, and endpoint. This approval lasts until you close Sked.'**
  String get schoolImportHttpConfirmationMessage;

  /// No description provided for @schoolImportParserCustomConfigIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.'**
  String get schoolImportParserCustomConfigIncomplete;

  /// No description provided for @schoolImportParserCurrentSourceCustom.
  ///
  /// In en, this message translates to:
  /// **'Parser: Custom ({model})'**
  String schoolImportParserCurrentSourceCustom(Object model);

  /// No description provided for @privacyViewFullPolicy.
  ///
  /// In en, this message translates to:
  /// **'View full privacy policy'**
  String get privacyViewFullPolicy;

  /// No description provided for @privacyAgreeAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get privacyAgreeAndContinue;

  /// No description provided for @privacyDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get privacyDecline;

  /// No description provided for @privacyDeclineWebHint.
  ///
  /// In en, this message translates to:
  /// **'This browser environment does not allow the app to close the page for you. If you do not agree, please close this tab or window yourself.'**
  String get privacyDeclineWebHint;

  /// No description provided for @defaultPeriodTimeSetName.
  ///
  /// In en, this message translates to:
  /// **'Default periods'**
  String get defaultPeriodTimeSetName;

  /// No description provided for @periodTimeSetFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Period times'**
  String get periodTimeSetFallbackName;

  /// No description provided for @untitledTimetableName.
  ///
  /// In en, this message translates to:
  /// **'Untitled timetable'**
  String get untitledTimetableName;

  /// No description provided for @newTimetableName.
  ///
  /// In en, this message translates to:
  /// **'New timetable'**
  String get newTimetableName;

  /// No description provided for @newPeriodTimeSetName.
  ///
  /// In en, this message translates to:
  /// **'New period time set'**
  String get newPeriodTimeSetName;

  /// No description provided for @emptyTimetableName.
  ///
  /// In en, this message translates to:
  /// **'Empty timetable'**
  String get emptyTimetableName;

  /// Fallback period time set name generated from an imported timetable name.
  ///
  /// In en, this message translates to:
  /// **'{name} periods'**
  String importedPeriodTimeSetName(Object name);

  /// No description provided for @importFileTypeMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Import file type does not match.'**
  String get importFileTypeMismatchMessage;

  /// No description provided for @importFileVersionUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'This import file version is not supported yet.'**
  String get importFileVersionUnsupportedMessage;

  /// No description provided for @noPeriodTimesInImportMessage.
  ///
  /// In en, this message translates to:
  /// **'No period times found in the import file.'**
  String get noPeriodTimesInImportMessage;

  /// No description provided for @selectAtLeastOneTimetableMessage.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one timetable.'**
  String get selectAtLeastOneTimetableMessage;

  /// No description provided for @noExportableTimetableMessage.
  ///
  /// In en, this message translates to:
  /// **'There is no timetable available to export.'**
  String get noExportableTimetableMessage;

  /// No description provided for @replaceActiveRequiresSingleTimetableMessage.
  ///
  /// In en, this message translates to:
  /// **'Replacing the current timetable only supports selecting one timetable.'**
  String get replaceActiveRequiresSingleTimetableMessage;

  /// No description provided for @noActiveTimetableToReplaceMessage.
  ///
  /// In en, this message translates to:
  /// **'There is no current timetable to replace.'**
  String get noActiveTimetableToReplaceMessage;

  /// No description provided for @periodTimeSetInUseMessage.
  ///
  /// In en, this message translates to:
  /// **'This period time set is still used by {count} timetable(s). Reassign them before deleting.'**
  String periodTimeSetInUseMessage(int count);

  /// No description provided for @weekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySunday;

  /// No description provided for @weekdayShortMonday.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayShortMonday;

  /// No description provided for @weekdayShortTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayShortTuesday;

  /// No description provided for @weekdayShortWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayShortWednesday;

  /// No description provided for @weekdayShortThursday.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayShortThursday;

  /// No description provided for @weekdayShortFriday.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayShortFriday;

  /// No description provided for @weekdayShortSaturday.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayShortSaturday;

  /// No description provided for @weekdayShortSunday.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayShortSunday;

  /// No description provided for @monthJanuary.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJanuary;

  /// No description provided for @monthFebruary.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFebruary;

  /// No description provided for @monthMarch.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMarch;

  /// No description provided for @monthApril.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApril;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJune.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJune;

  /// No description provided for @monthJuly.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJuly;

  /// No description provided for @monthAugust.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAugust;

  /// No description provided for @monthSeptember.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSeptember;

  /// No description provided for @monthOctober.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOctober;

  /// No description provided for @monthNovember.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNovember;

  /// No description provided for @monthDecember.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDecember;

  /// No description provided for @semesterWeeksWholeTerm.
  ///
  /// In en, this message translates to:
  /// **'All semester'**
  String get semesterWeeksWholeTerm;

  /// No description provided for @semesterWeeksRange.
  ///
  /// In en, this message translates to:
  /// **'Weeks {start}-{end}'**
  String semesterWeeksRange(Object start, Object end);

  /// No description provided for @semesterWeeksList.
  ///
  /// In en, this message translates to:
  /// **'Weeks {value}'**
  String semesterWeeksList(Object value);

  /// No description provided for @generalSchedule.
  ///
  /// In en, this message translates to:
  /// **'General schedule'**
  String get generalSchedule;

  /// No description provided for @studentTimetable.
  ///
  /// In en, this message translates to:
  /// **'Student timetable'**
  String get studentTimetable;

  /// No description provided for @firstLaunchTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your starting mode'**
  String get firstLaunchTitle;

  /// No description provided for @firstLaunchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the workspace you use most. You can switch modes later.'**
  String get firstLaunchSubtitle;

  /// No description provided for @firstLaunchStudentDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage timetables, courses, weeks, period times, and imports.'**
  String get firstLaunchStudentDesc;

  /// No description provided for @firstLaunchGeneralDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage calendars, events, reminders, and JSON / ICS data.'**
  String get firstLaunchGeneralDesc;

  /// No description provided for @firstLaunchStartStudent.
  ///
  /// In en, this message translates to:
  /// **'Start with timetable'**
  String get firstLaunchStartStudent;

  /// No description provided for @firstLaunchStartGeneral.
  ///
  /// In en, this message translates to:
  /// **'Start with schedule'**
  String get firstLaunchStartGeneral;

  /// No description provided for @firstLaunchPrivacyHint.
  ///
  /// In en, this message translates to:
  /// **'You will review and agree to the privacy policy before entering.'**
  String get firstLaunchPrivacyHint;

  /// No description provided for @firstLaunchPreparingPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Preparing the privacy policy check...'**
  String get firstLaunchPreparingPrivacy;

  /// No description provided for @switchMode.
  ///
  /// In en, this message translates to:
  /// **'Switch mode'**
  String get switchMode;

  /// No description provided for @generalScheduleComingSoon.
  ///
  /// In en, this message translates to:
  /// **'General schedule coming soon'**
  String get generalScheduleComingSoon;

  /// No description provided for @switchToStudentTimetable.
  ///
  /// In en, this message translates to:
  /// **'Switch to Student timetable'**
  String get switchToStudentTimetable;

  /// No description provided for @mySchedule.
  ///
  /// In en, this message translates to:
  /// **'My schedule'**
  String get mySchedule;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @addEvent.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get addEvent;

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEvent;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get eventTitle;

  /// No description provided for @eventTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get eventTitleRequired;

  /// No description provided for @eventStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get eventStartTime;

  /// No description provided for @eventEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get eventEndTime;

  /// No description provided for @eventDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get eventDate;

  /// No description provided for @eventTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get eventTime;

  /// No description provided for @eventNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get eventNotes;

  /// No description provided for @eventColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get eventColor;

  /// No description provided for @eventRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get eventRecurrence;

  /// No description provided for @recurrenceNone.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get recurrenceNone;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get recurrenceEndDate;

  /// No description provided for @recurrenceNoEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get recurrenceNoEndDate;

  /// No description provided for @recurrenceSetEndDate.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get recurrenceSetEndDate;

  /// No description provided for @recurrenceChangeEndDate.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get recurrenceChangeEndDate;

  /// No description provided for @repeatsWeekly.
  ///
  /// In en, this message translates to:
  /// **'Repeats weekly'**
  String get repeatsWeekly;

  /// No description provided for @recurrenceUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String recurrenceUntil(Object date);

  /// No description provided for @switchToGeneralSchedule.
  ///
  /// In en, this message translates to:
  /// **'Switch to General schedule'**
  String get switchToGeneralSchedule;

  /// No description provided for @generalDisplaySettings.
  ///
  /// In en, this message translates to:
  /// **'General display settings'**
  String get generalDisplaySettings;

  /// No description provided for @generalDisplaySettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Toggles for the general schedule view'**
  String get generalDisplaySettingsDesc;

  /// No description provided for @closePopupOnOutsideTap.
  ///
  /// In en, this message translates to:
  /// **'Close popup on tap outside'**
  String get closePopupOnOutsideTap;

  /// No description provided for @showGridLines.
  ///
  /// In en, this message translates to:
  /// **'Show grid lines'**
  String get showGridLines;

  /// No description provided for @generalScheduleImportExport.
  ///
  /// In en, this message translates to:
  /// **'Schedule import & export'**
  String get generalScheduleImportExport;

  /// No description provided for @generalScheduleImportExportDesc.
  ///
  /// In en, this message translates to:
  /// **'Import or share general schedules'**
  String get generalScheduleImportExportDesc;

  /// No description provided for @importGeneralSchedules.
  ///
  /// In en, this message translates to:
  /// **'Import schedules'**
  String get importGeneralSchedules;

  /// No description provided for @importGeneralSchedulesDesc.
  ///
  /// In en, this message translates to:
  /// **'Read schedules from a JSON file'**
  String get importGeneralSchedulesDesc;

  /// No description provided for @shareGeneralSchedules.
  ///
  /// In en, this message translates to:
  /// **'Share schedules'**
  String get shareGeneralSchedules;

  /// No description provided for @shareGeneralSchedulesDesc.
  ///
  /// In en, this message translates to:
  /// **'Share schedules as a JSON file'**
  String get shareGeneralSchedulesDesc;

  /// No description provided for @saveGeneralSchedules.
  ///
  /// In en, this message translates to:
  /// **'Save schedules'**
  String get saveGeneralSchedules;

  /// No description provided for @saveGeneralSchedulesDesc.
  ///
  /// In en, this message translates to:
  /// **'Save schedules as a JSON file'**
  String get saveGeneralSchedulesDesc;

  /// No description provided for @selectSchedulesToExport.
  ///
  /// In en, this message translates to:
  /// **'Select schedules to export'**
  String get selectSchedulesToExport;

  /// No description provided for @selectSchedulesToImport.
  ///
  /// In en, this message translates to:
  /// **'Select schedules to import'**
  String get selectSchedulesToImport;

  /// No description provided for @generalScheduleEventCount.
  ///
  /// In en, this message translates to:
  /// **'Events: {count}'**
  String generalScheduleEventCount(int count);

  /// No description provided for @importedSchedulesCount.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} schedules'**
  String importedSchedulesCount(int count);

  /// No description provided for @replaceActiveSchedulePrompt.
  ///
  /// In en, this message translates to:
  /// **'Replace current schedule with the imported one?'**
  String get replaceActiveSchedulePrompt;

  /// No description provided for @addAsNewSchedule.
  ///
  /// In en, this message translates to:
  /// **'Add as new'**
  String get addAsNewSchedule;

  /// No description provided for @selectAtLeastOneScheduleMessage.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one schedule.'**
  String get selectAtLeastOneScheduleMessage;

  /// No description provided for @noExportableScheduleMessage.
  ///
  /// In en, this message translates to:
  /// **'No schedule available to export.'**
  String get noExportableScheduleMessage;

  /// No description provided for @noSchedulesInImportMessage.
  ///
  /// In en, this message translates to:
  /// **'Import file contains no schedules.'**
  String get noSchedulesInImportMessage;

  /// No description provided for @replaceActiveRequiresSingleScheduleMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose exactly one schedule to replace the current one.'**
  String get replaceActiveRequiresSingleScheduleMessage;

  /// No description provided for @noActiveScheduleToReplaceMessage.
  ///
  /// In en, this message translates to:
  /// **'No current schedule to replace.'**
  String get noActiveScheduleToReplaceMessage;

  /// No description provided for @calendars.
  ///
  /// In en, this message translates to:
  /// **'Calendars'**
  String get calendars;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @viewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get viewWeek;

  /// No description provided for @viewDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get viewDay;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @viewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get viewMonth;

  /// No description provided for @eventDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Event duplicated'**
  String get eventDuplicated;

  /// No description provided for @searchEvents.
  ///
  /// In en, this message translates to:
  /// **'Search events'**
  String get searchEvents;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @filterByColor.
  ///
  /// In en, this message translates to:
  /// **'Filter by color'**
  String get filterByColor;

  /// No description provided for @allColors.
  ///
  /// In en, this message translates to:
  /// **'All colors'**
  String get allColors;

  /// No description provided for @upcomingEventsCount.
  ///
  /// In en, this message translates to:
  /// **'Upcoming {count}'**
  String upcomingEventsCount(int count);

  /// No description provided for @overdueEventsCount.
  ///
  /// In en, this message translates to:
  /// **'Overdue {count}'**
  String overdueEventsCount(int count);

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All-day'**
  String get allDay;

  /// No description provided for @moreEvents.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreEvents(int count);

  /// No description provided for @noMatchingEvents.
  ///
  /// In en, this message translates to:
  /// **'No matching events'**
  String get noMatchingEvents;

  /// No description provided for @noUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get noUpcomingEvents;

  /// No description provided for @addCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add calendar'**
  String get addCalendar;

  /// No description provided for @newCalendar.
  ///
  /// In en, this message translates to:
  /// **'New calendar'**
  String get newCalendar;

  /// No description provided for @hideCalendar.
  ///
  /// In en, this message translates to:
  /// **'Hide calendar'**
  String get hideCalendar;

  /// No description provided for @showCalendar.
  ///
  /// In en, this message translates to:
  /// **'Show calendar'**
  String get showCalendar;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameCalendar.
  ///
  /// In en, this message translates to:
  /// **'Rename calendar'**
  String get renameCalendar;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @deleteCalendar.
  ///
  /// In en, this message translates to:
  /// **'Delete calendar'**
  String get deleteCalendar;

  /// No description provided for @deleteCalendarMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteCalendarMessage(Object name);

  /// No description provided for @deleteThisOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Delete this'**
  String get deleteThisOccurrence;

  /// No description provided for @deleteFutureOccurrences.
  ///
  /// In en, this message translates to:
  /// **'Delete future'**
  String get deleteFutureOccurrences;

  /// No description provided for @deleteAllOccurrences.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteAllOccurrences;

  /// No description provided for @duplicateEvent.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateEvent;

  /// No description provided for @repeatsDaily.
  ///
  /// In en, this message translates to:
  /// **'Repeats daily'**
  String get repeatsDaily;

  /// No description provided for @repeatsMonthly.
  ///
  /// In en, this message translates to:
  /// **'Repeats monthly'**
  String get repeatsMonthly;

  /// No description provided for @repeatsEvery.
  ///
  /// In en, this message translates to:
  /// **'Repeats every {interval} {unit}'**
  String repeatsEvery(int interval, Object unit);

  /// No description provided for @recurrenceCountTimes.
  ///
  /// In en, this message translates to:
  /// **'{count} times'**
  String recurrenceCountTimes(int count);

  /// No description provided for @recurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurrenceMonthly;

  /// No description provided for @recurrenceCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get recurrenceCustom;

  /// No description provided for @recurrenceEvery.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get recurrenceEvery;

  /// No description provided for @recurrenceUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get recurrenceUnit;

  /// No description provided for @recurrenceDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get recurrenceDays;

  /// No description provided for @recurrenceWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get recurrenceWeeks;

  /// No description provided for @recurrenceMonths.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get recurrenceMonths;

  /// No description provided for @recurrenceRepeatCount.
  ///
  /// In en, this message translates to:
  /// **'Repeat count'**
  String get recurrenceRepeatCount;

  /// No description provided for @recurrenceNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get recurrenceNoLimit;

  /// No description provided for @recurrencePositiveNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get recurrencePositiveNumber;

  /// No description provided for @clearEndDate.
  ///
  /// In en, this message translates to:
  /// **'Clear end date'**
  String get clearEndDate;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get pickDate;

  /// No description provided for @pickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick time'**
  String get pickTime;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'In-app reminder'**
  String get reminder;

  /// No description provided for @reminderAtStart.
  ///
  /// In en, this message translates to:
  /// **'At start'**
  String get reminderAtStart;

  /// No description provided for @reminderMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String reminderMinutesBefore(int minutes);

  /// No description provided for @reminderHourBefore.
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get reminderHourBefore;

  /// No description provided for @reminderDayBefore.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get reminderDayBefore;

  /// No description provided for @markReminderHandled.
  ///
  /// In en, this message translates to:
  /// **'Mark handled'**
  String get markReminderHandled;

  /// No description provided for @restoreReminder.
  ///
  /// In en, this message translates to:
  /// **'Restore in-app reminder'**
  String get restoreReminder;

  /// No description provided for @reminderHandled.
  ///
  /// In en, this message translates to:
  /// **'In-app reminder marked handled'**
  String get reminderHandled;

  /// No description provided for @reminderRestored.
  ///
  /// In en, this message translates to:
  /// **'In-app reminder restored'**
  String get reminderRestored;

  /// No description provided for @reminderUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get reminderUpcoming;

  /// No description provided for @reminderOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get reminderOverdue;

  /// No description provided for @showWeekends.
  ///
  /// In en, this message translates to:
  /// **'Show weekends'**
  String get showWeekends;

  /// No description provided for @startHour.
  ///
  /// In en, this message translates to:
  /// **'Start hour'**
  String get startHour;

  /// No description provided for @endHour.
  ///
  /// In en, this message translates to:
  /// **'End hour'**
  String get endHour;

  /// No description provided for @timeGridDensity.
  ///
  /// In en, this message translates to:
  /// **'Time grid density'**
  String get timeGridDensity;

  /// No description provided for @importJsonFile.
  ///
  /// In en, this message translates to:
  /// **'Import JSON file'**
  String get importJsonFile;

  /// No description provided for @pasteJson.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON'**
  String get pasteJson;

  /// No description provided for @importGeneralSchedulesJsonTextDesc.
  ///
  /// In en, this message translates to:
  /// **'Import calendars from copied JSON'**
  String get importGeneralSchedulesJsonTextDesc;

  /// No description provided for @importIcsFile.
  ///
  /// In en, this message translates to:
  /// **'Import ICS file'**
  String get importIcsFile;

  /// No description provided for @importIcsFileDesc.
  ///
  /// In en, this message translates to:
  /// **'Read events from an .ics calendar file'**
  String get importIcsFileDesc;

  /// No description provided for @pasteIcs.
  ///
  /// In en, this message translates to:
  /// **'Paste ICS'**
  String get pasteIcs;

  /// No description provided for @pasteIcsDesc.
  ///
  /// In en, this message translates to:
  /// **'Import events from copied calendar text'**
  String get pasteIcsDesc;

  /// No description provided for @copyJson.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON'**
  String get copyJson;

  /// No description provided for @copyJsonDesc.
  ///
  /// In en, this message translates to:
  /// **'Copy selected calendars as JSON text'**
  String get copyJsonDesc;

  /// No description provided for @shareIcs.
  ///
  /// In en, this message translates to:
  /// **'Share ICS'**
  String get shareIcs;

  /// No description provided for @shareIcsDesc.
  ///
  /// In en, this message translates to:
  /// **'Share selected calendars as .ics'**
  String get shareIcsDesc;

  /// No description provided for @saveIcs.
  ///
  /// In en, this message translates to:
  /// **'Save ICS'**
  String get saveIcs;

  /// No description provided for @saveIcsDesc.
  ///
  /// In en, this message translates to:
  /// **'Save selected calendars as .ics'**
  String get saveIcsDesc;

  /// No description provided for @copyIcs.
  ///
  /// In en, this message translates to:
  /// **'Copy ICS'**
  String get copyIcs;

  /// No description provided for @copyIcsDesc.
  ///
  /// In en, this message translates to:
  /// **'Copy selected calendars as ICS text'**
  String get copyIcsDesc;

  /// No description provided for @importIcs.
  ///
  /// In en, this message translates to:
  /// **'Import ICS'**
  String get importIcs;

  /// No description provided for @icsContent.
  ///
  /// In en, this message translates to:
  /// **'ICS content'**
  String get icsContent;

  /// No description provided for @pasteIcsContentHint.
  ///
  /// In en, this message translates to:
  /// **'Paste BEGIN:VCALENDAR content here'**
  String get pasteIcsContentHint;

  /// No description provided for @importIcsPreviewPrompt.
  ///
  /// In en, this message translates to:
  /// **'Found {count} events. Import as a new calendar or replace the active calendar?'**
  String importIcsPreviewPrompt(int count);

  /// No description provided for @importedSchedulesWithWarnings.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} schedules with {warningCount} warnings'**
  String importedSchedulesWithWarnings(int count, int warningCount);

  /// No description provided for @importWarningSkippedMissingStart.
  ///
  /// In en, this message translates to:
  /// **'Skipped an event without a start time.'**
  String get importWarningSkippedMissingStart;

  /// No description provided for @importWarningSkippedUnsupportedStart.
  ///
  /// In en, this message translates to:
  /// **'Skipped an event with an unsupported start time.'**
  String get importWarningSkippedUnsupportedStart;

  /// No description provided for @importWarningAdjustedEnd.
  ///
  /// In en, this message translates to:
  /// **'Adjusted an event whose end time was not after its start.'**
  String get importWarningAdjustedEnd;

  /// No description provided for @importWarningUnsupportedFields.
  ///
  /// In en, this message translates to:
  /// **'Unsupported ICS fields were added to notes: {fields}'**
  String importWarningUnsupportedFields(Object fields);

  /// No description provided for @importWarningUnsupportedRRuleFrequency.
  ///
  /// In en, this message translates to:
  /// **'Ignored unsupported repeat frequency: {frequency}'**
  String importWarningUnsupportedRRuleFrequency(Object frequency);

  /// No description provided for @selectCalendarsToCopyIcs.
  ///
  /// In en, this message translates to:
  /// **'Select calendars to copy as ICS'**
  String get selectCalendarsToCopyIcs;

  /// No description provided for @selectCalendarsToExportIcs.
  ///
  /// In en, this message translates to:
  /// **'Select calendars to export as ICS'**
  String get selectCalendarsToExportIcs;

  /// No description provided for @exportIcsText.
  ///
  /// In en, this message translates to:
  /// **'Export ICS text'**
  String get exportIcsText;

  /// No description provided for @exportJsonText.
  ///
  /// In en, this message translates to:
  /// **'Export JSON text'**
  String get exportJsonText;

  /// No description provided for @dataRestoredFromBackupNotice.
  ///
  /// In en, this message translates to:
  /// **'App data was restored from the previous backup because the main file failed to load.'**
  String get dataRestoredFromBackupNotice;

  /// No description provided for @dataBackupRestoreFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'Both the main data file and its backup are damaged. The app is now using a fresh state.'**
  String get dataBackupRestoreFailedNotice;

  /// No description provided for @dataRecoveryCorruptTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data needs recovery'**
  String get dataRecoveryCorruptTitle;

  /// No description provided for @dataRecoveryCorruptMessage.
  ///
  /// In en, this message translates to:
  /// **'Sked could not read the main data file or its backup. Protected copies were created before writes were blocked.'**
  String get dataRecoveryCorruptMessage;

  /// No description provided for @dataRecoveryIoFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage is unavailable'**
  String get dataRecoveryIoFailureTitle;

  /// No description provided for @dataRecoveryIoFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Sked cannot access local storage right now. Retry after checking storage access or device availability. Existing data will not be overwritten.'**
  String get dataRecoveryIoFailureMessage;

  /// No description provided for @dataRecoveryUnsupportedVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Sked to open this data'**
  String get dataRecoveryUnsupportedVersionTitle;

  /// No description provided for @dataRecoveryUnsupportedVersionMessage.
  ///
  /// In en, this message translates to:
  /// **'This data was created by a newer version of Sked. Update the app before trying again. Starting fresh is disabled to protect it.'**
  String get dataRecoveryUnsupportedVersionMessage;

  /// No description provided for @dataRecoveryRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dataRecoveryRetryAction;

  /// No description provided for @dataRecoveryArtifactsHint.
  ///
  /// In en, this message translates to:
  /// **'Recovery files or affected storage locations are listed below. Keep any files unchanged until your data is recovered.'**
  String get dataRecoveryArtifactsHint;

  /// No description provided for @dataRecoveryArtifactsAction.
  ///
  /// In en, this message translates to:
  /// **'Show recovery files and locations'**
  String get dataRecoveryArtifactsAction;

  /// No description provided for @dataRecoveryStartFreshAction.
  ///
  /// In en, this message translates to:
  /// **'Start with new data'**
  String get dataRecoveryStartFreshAction;

  /// No description provided for @dataRecoveryStartFreshConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with new data?'**
  String get dataRecoveryStartFreshConfirmTitle;

  /// No description provided for @dataRecoveryStartFreshConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Protected copies will be kept, but Sked will create a new local data file. Continue only if you do not want to retry recovery first.'**
  String get dataRecoveryStartFreshConfirmMessage;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @timeGridMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String timeGridMinutes(int minutes);

  /// No description provided for @reminderInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get reminderInProgress;

  /// No description provided for @deleteCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete course'**
  String get deleteCourseTitle;

  /// No description provided for @deleteCourseMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this course?'**
  String get deleteCourseMessage;

  /// No description provided for @showLunarCalendar.
  ///
  /// In en, this message translates to:
  /// **'Show lunar calendar'**
  String get showLunarCalendar;

  /// No description provided for @monthDayEvents.
  ///
  /// In en, this message translates to:
  /// **'{day}, {count} events'**
  String monthDayEvents(int day, int count);

  /// No description provided for @defaultView.
  ///
  /// In en, this message translates to:
  /// **'Default view'**
  String get defaultView;

  /// No description provided for @generalDefaultViewSection.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get generalDefaultViewSection;

  /// No description provided for @generalScheduleDisplaySection.
  ///
  /// In en, this message translates to:
  /// **'Schedule display'**
  String get generalScheduleDisplaySection;

  /// No description provided for @generalTimeGridSection.
  ///
  /// In en, this message translates to:
  /// **'Time grid'**
  String get generalTimeGridSection;

  /// No description provided for @generalPopupSection.
  ///
  /// In en, this message translates to:
  /// **'Popup behavior'**
  String get generalPopupSection;

  /// No description provided for @schoolWebImportSignInConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Open school sign-in?'**
  String get schoolWebImportSignInConsentTitle;

  /// No description provided for @schoolWebImportSignInConsentMessage.
  ///
  /// In en, this message translates to:
  /// **'School sign-in may submit credentials through forms or server redirects to the school and its sign-in providers. Android cannot pause every such transfer for a separate destination prompt. Continue only if you trust them for this import session:\n\n{origin}'**
  String schoolWebImportSignInConsentMessage(Object origin);

  /// No description provided for @schoolWebImportInsecureSignInConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Open an insecure school sign-in?'**
  String get schoolWebImportInsecureSignInConsentTitle;

  /// No description provided for @schoolWebImportInsecureSignInConsentMessage.
  ///
  /// In en, this message translates to:
  /// **'This school sign-in uses HTTP. Your credentials and page content can be read or changed by anyone who can observe or alter this connection. Continue only if you accept this risk for:\n\n{origin}'**
  String schoolWebImportInsecureSignInConsentMessage(Object origin);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'bg',
    'cs',
    'da',
    'de',
    'el',
    'en',
    'es',
    'et',
    'fi',
    'fr',
    'hi',
    'hu',
    'it',
    'ja',
    'ko',
    'nl',
    'pl',
    'pt',
    'ro',
    'ru',
    'sl',
    'sv',
    'th',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bg':
      return AppLocalizationsBg();
    case 'cs':
      return AppLocalizationsCs();
    case 'da':
      return AppLocalizationsDa();
    case 'de':
      return AppLocalizationsDe();
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'et':
      return AppLocalizationsEt();
    case 'fi':
      return AppLocalizationsFi();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'hu':
      return AppLocalizationsHu();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ro':
      return AppLocalizationsRo();
    case 'ru':
      return AppLocalizationsRu();
    case 'sl':
      return AppLocalizationsSl();
    case 'sv':
      return AppLocalizationsSv();
    case 'th':
      return AppLocalizationsTh();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
