// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'सप्ताह $week';
  }

  @override
  String get addCourse => 'कोर्स जोड़ें';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get multiTimetableSwitch => 'टाइमटेबल बदलें';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'वर्तमान टाइमटेबल · $weeks सप्ताह';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'बदलने के लिए टैप करें · $weeks सप्ताह';
  }

  @override
  String get editTimetable => 'टाइमटेबल संपादित करें';

  @override
  String get schoolImportResultEditorTitle =>
      'पार्स किया गया परिणाम संपादित करें';

  @override
  String get schoolImportParsePageTitle => 'टाइमटेबल पार्स करें';

  @override
  String get schoolImportParsePageParsing => 'पार्स किया जा रहा है…';

  @override
  String get schoolImportParsePageFailed => 'पार्सिंग विफल';

  @override
  String get schoolImportParsePageComplete => 'पार्सिंग पूरी हुई';

  @override
  String get schoolImportParsePageContinue => 'जारी रखें';

  @override
  String get schoolImportParsePageRawContent => 'कच्ची प्रतिक्रिया';

  @override
  String get schoolImportParsePageExpandRaw => 'कच्ची प्रतिक्रिया विस्तृत करें';

  @override
  String get schoolImportParsePageCollapseRaw =>
      'कच्ची प्रतिक्रिया संक्षिप्त करें';

  @override
  String get schoolImportExpandWarnings => 'आयात चेतावनियाँ खोलें';

  @override
  String get schoolImportCollapseWarnings => 'आयात चेतावनियाँ समेटें';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'कुछ कोर्स $weekवें सप्ताह तक चलते हैं।';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle => 'मौजूदा टाइमटेबल बदलें?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'आयात किया गया टाइमटेबल मौजूदा टाइमटेबल की जगह लेगा।';

  @override
  String get createTimetable => 'नया टाइमटेबल';

  @override
  String get jumpToWeek => 'सप्ताह पर जाएँ';

  @override
  String get timetable => 'टाइमटेबल';

  @override
  String get themeWorkspaceSchedule => 'शेड्यूल';

  @override
  String get timetableName => 'टाइमटेबल का नाम';

  @override
  String get timetableNameRequired => 'टाइमटेबल का नाम आवश्यक है';

  @override
  String get totalWeeks => 'कुल सप्ताह';

  @override
  String get delete => 'हटाएँ';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सहेजें';

  @override
  String get deleteTimetableTitle => 'टाइमटेबल हटाएँ';

  @override
  String deleteTimetableMessage(Object name) {
    return '\"$name\" हटाएँ?';
  }

  @override
  String get noTimetableTitle => 'अभी तक कोई टाइमटेबल नहीं';

  @override
  String get noTimetableMessage =>
      'एक टाइमटेबल बनाएँ या JSON फ़ाइल से आयात करें।';

  @override
  String get importTimetable => 'टाइमटेबल आयात करें';

  @override
  String get courseName => 'कोर्स का नाम';

  @override
  String get location => 'स्थान';

  @override
  String get dayOfWeek => 'दिन';

  @override
  String get semesterWeeks => 'सप्ताह';

  @override
  String get startTime => 'प्रारंभ समय';

  @override
  String get endTime => 'समाप्ति समय';

  @override
  String get linkedPeriods => 'जुड़ी हुई अवधि';

  @override
  String get linkedPeriodsUnmatched =>
      'वर्तमान समय के लिए कोई अवधि मेल नहीं खाई। मैन्युअल रूप से चुनने के लिए टैप करें।';

  @override
  String periodRangeLabel(int start, int end) {
    return 'अवधि $start-$end';
  }

  @override
  String get teacherName => 'शिक्षक';

  @override
  String get credits => 'क्रेडिट';

  @override
  String get remarks => 'टिप्पणियाँ';

  @override
  String get customFields => 'कस्टम फ़ील्ड';

  @override
  String get customFieldsHint => 'प्रति पंक्ति एक, फ़ॉर्मेट: key:value';

  @override
  String get customFieldsInvalidJson =>
      'कोई मान्य JSON ऑब्जेक्ट दर्ज करें या फ़ील्ड खाली करें।';

  @override
  String get more => 'अधिक';

  @override
  String get selectDayOfWeek => 'दिन चुनें';

  @override
  String get selectSemesterWeeks => 'सप्ताह चुनें';

  @override
  String get selectAll => 'सभी चुनें';

  @override
  String get clear => 'साफ़ करें';

  @override
  String get confirm => 'पुष्टि करें';

  @override
  String get selectLinkedPeriods => 'जुड़ी हुई अवधि चुनें';

  @override
  String get addCourseTitle => 'कोर्स जोड़ें';

  @override
  String get editCourseTitle => 'कोर्स संपादित करें';

  @override
  String get editCourseTooltip => 'कोर्स संपादित करें';

  @override
  String get place => 'स्थान';

  @override
  String get time => 'समय';

  @override
  String get notFilled => 'भरा नहीं गया';

  @override
  String get none => 'कोई नहीं';

  @override
  String get conflictCourses => 'टकराने वाले कोर्स';

  @override
  String get locationNotFilled => 'स्थान भरा नहीं गया';

  @override
  String get setAsDisplayed => 'प्रदर्शित के रूप में सेट करें';

  @override
  String get editThisCourse => 'इस कोर्स को संपादित करें';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsSectionTimetable => 'टाइमटेबल';

  @override
  String get settingsSectionGeneralSchedule => 'सामान्य शेड्यूल';

  @override
  String get settingsSectionAppearance => 'दिखावट';

  @override
  String get settingsSectionApp => 'ऐप';

  @override
  String get settingsSectionWorkspace => 'कार्यस्थान';

  @override
  String get settingsSectionAppearanceLanguage => 'दिखावट और भाषा';

  @override
  String get settingsSectionDataSecurity => 'डेटा और सुरक्षा';

  @override
  String get settingsSectionAbout => 'Sked के बारे में';

  @override
  String get noTimetableSettings =>
      'सेटिंग्स के लिए अभी कोई टाइमटेबल उपलब्ध नहीं है।';

  @override
  String get semesterStartDate => 'सेमेस्टर प्रारंभ तिथि';

  @override
  String get periodTimeSets => 'अवधि समय सेट';

  @override
  String get noPeriodTimeAvailable => 'कोई उपलब्ध अवधि समय सेट नहीं';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count अवधि';
  }

  @override
  String get coursePopupDismissSetting =>
      'बाहर टैप करके कोर्स पॉपअप बंद करने दें';

  @override
  String get coursePopupDismissSettingHint =>
      'इसे बंद करने पर स्वाइप-डाउन से बंद करना भी अक्षम हो जाएगा।';

  @override
  String get preserveTimetableGaps => 'टाइमटेबल के अंतराल बनाए रखें';

  @override
  String get preserveTimetableGapsHint =>
      'बंद होने पर लंच और ब्रेक के अंतराल समेट दिए जाएँगे ताकि बाद की कक्षाएँ ऊपर खिसक जाएँ।';

  @override
  String get showPastEndedCourses => 'समाप्त हो चुके कोर्स दिखाएँ';

  @override
  String get showPastEndedCoursesHint =>
      'जो कोर्स वास्तविक वर्तमान सप्ताह तक समाप्त हो चुके हैं, उन्हें हल्के ग्रे रंग में दिखाएँ।';

  @override
  String get showFutureCourses => 'भविष्य के कोर्स दिखाएँ';

  @override
  String get showFutureCoursesHint =>
      'जो कोर्स इस सप्ताह सक्रिय नहीं हैं लेकिन आने वाले सप्ताहों में दिखाई देंगे, उन्हें ग्रे शैली में दिखाएँ।';

  @override
  String get timetableDisplaySettings => 'टाइमटेबल प्रदर्शन और इंटरैक्शन';

  @override
  String get timetableDisplaySettingsDesc =>
      'कक्षा प्रदर्शन, लेआउट, सप्ताह जेस्चर और तुरंत जोड़ना';

  @override
  String get showTimetableGridLines => 'टाइमटेबल ग्रिड लाइनें दिखाएँ';

  @override
  String get showTimetableGridLinesHint =>
      'नियंत्रित करें कि टाइमटेबल में क्षैतिज और ऊर्ध्वाधर ग्रिड लाइनें दिखें या नहीं।';

  @override
  String get timetableHorizontalLayoutSection => 'क्षैतिज लेआउट और जेस्चर';

  @override
  String get fitDaySelectorToWidth => 'दिन चयनकर्ता को स्क्रीन में समाएँ';

  @override
  String get fitDaySelectorToWidthHint =>
      'जहाँ संभव हो, सभी सात दिन स्क्रीन पर दिखाएँ; निश्चित चौड़ाई और स्क्रॉलिंग के लिए इसे बंद करें।';

  @override
  String get fitWeekColumnsToWidth => 'सप्ताह के कॉलम स्क्रीन में समाएँ';

  @override
  String get fitWeekColumnsToWidthHint =>
      'जहाँ संभव हो, टाइमटेबल के सभी सात कॉलम स्क्रीन पर दिखाएँ; निश्चित चौड़ाई और स्क्रॉलिंग के लिए इसे बंद करें।';

  @override
  String get enableWeekSwipeNavigation => 'स्वाइप करके सप्ताह बदलें';

  @override
  String get enableWeekSwipeNavigationHint =>
      'दूसरे सप्ताह पर जाने के लिए बाएँ या दाएँ स्वाइप करें। निश्चित चौड़ाई होने पर पहले किनारे से आगे खींचें।';

  @override
  String get liveCourseOutlineColor => 'कोर्स आउटलाइन रंग';

  @override
  String get liveCourseOutlineColorHint =>
      'चुनें कि आउटलाइन वर्तमान/अगले कोर्स पर लागू हो या वर्तमान पेज पर दिख रहे सभी कोर्स पर।';

  @override
  String get liveCourseOutlineSettings => 'कोर्स आउटलाइन';

  @override
  String get liveCourseOutlineSettingsHint =>
      'आउटलाइन सक्षम है या नहीं, उसका लक्ष्य क्या है, क्या वह थीम रंग का अनुसरण करती है, और प्रभावी आउटलाइन रंग क्या है, यह कॉन्फ़िगर करें।';

  @override
  String get liveCourseOutlineEnabled => 'आउटलाइन सक्षम करें';

  @override
  String get liveCourseOutlineFollowTheme => 'थीम रंग का अनुसरण करें';

  @override
  String get liveCourseOutlineTarget => 'आउटलाइन लक्ष्य';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'वर्तमान/अगला कोर्स';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'दिख रहे सभी कोर्स';

  @override
  String get liveCourseOutlineEffectiveColor => 'प्रभावी रंग';

  @override
  String get liveCourseOutlineCustomColor => 'कस्टम आउटलाइन रंग';

  @override
  String get liveCourseOutlineWidth => 'आउटलाइन चौड़ाई';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'भाषा';

  @override
  String get languagePageDescription =>
      'ऐप में वास्तव में उपलब्ध भाषाओं में से एक चुनें।';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API प्रतिक्रिया';

  @override
  String get theme => 'थीम';

  @override
  String get themeFollowSystem => 'सिस्टम के अनुसार';

  @override
  String get themeLight => 'हल्की';

  @override
  String get themeDark => 'गहरी';

  @override
  String get themeColor => 'थीम रंग';

  @override
  String get themeColorModeSingle => 'एकल थीम रंग';

  @override
  String get themeColorModeColorful => 'रंगीन';

  @override
  String get themeColorUiColors => 'UI रंग';

  @override
  String get themeColorCourseColors => 'कोर्स रंग';

  @override
  String get themeColorPrimary => 'प्राथमिक';

  @override
  String get themeColorSecondary => 'द्वितीयक';

  @override
  String get themeColorTertiary => 'तृतीयक';

  @override
  String get themeColorCourseText => 'कोर्स पाठ';

  @override
  String get themeColorCourseTextAuto => 'स्वचालित';

  @override
  String get themeColorCourseTextCustom => 'कस्टम रंग';

  @override
  String get themeColorCourseColorsEmpty =>
      'टाइमटेबल आयात करने के बाद कोर्स रंग बनाए जाएँगे।';

  @override
  String get themeCustomColor => 'कस्टम रंग';

  @override
  String get themeApplyCustomColor => 'रंग लागू करें';

  @override
  String get themeApplySettings => 'सेटिंग्स लागू करें';

  @override
  String get dataImportExport => 'डेटा आयात और निर्यात';

  @override
  String get dataImportExportDesc =>
      'पूरा डेटा या अलग-अलग टाइमटेबल आयात करें, या वर्तमान/सभी टाइमटेबल निर्यात करें।';

  @override
  String get appBackupTitle => 'ऐप बैकअप और पुनर्स्थापना';

  @override
  String get appBackupSubtitle =>
      'टाइमटेबल, शेड्यूल, सेटिंग और स्कूल साइटों का बैकअप लें या पुनर्स्थापित करें। API कुंजियां शामिल नहीं हैं।';

  @override
  String get appBackupSheetSubtitle =>
      'पूरा पुनर्स्थापन वर्तमान ऐप डेटा को बदल देता है। AI API कुंजियां सुरक्षित संग्रहण में रहती हैं और बैकअप फ़ाइलों में नहीं लिखी जातीं।';

  @override
  String get restoreBackupFileTitle => 'JSON फ़ाइल से पुनर्स्थापित करें';

  @override
  String get restoreBackupFileSubtitle =>
      'पूर्ण Sked बैकअप फ़ाइल चुनें। पुनर्स्थापना से पहले आप पुष्टि करेंगे।';

  @override
  String get restoreBackupTextTitle => 'बैकअप JSON पेस्ट करें';

  @override
  String get restoreBackupTextSubtitle =>
      'पूर्ण बैकअप पेस्ट करें और वर्तमान ऐप डेटा पुनर्स्थापित करें।';

  @override
  String get shareBackupTitle => 'बैकअप फ़ाइल साझा करें';

  @override
  String get shareBackupSubtitle =>
      'पूरा ऐप डेटा JSON के रूप में निर्यात करें। API कुंजियां शामिल नहीं की जाएंगी।';

  @override
  String get saveBackupTitle => 'बैकअप फ़ाइल सहेजें';

  @override
  String get saveBackupSubtitle =>
      'पूर्ण ऐप बैकअप को स्थानीय फ़ाइल में सहेजें।';

  @override
  String get copyBackupTitle => 'बैकअप टेक्स्ट कॉपी करें';

  @override
  String get copyBackupSubtitle =>
      'पूर्ण बैकअप JSON दिखाएं ताकि आप उसे कॉपी या अस्थायी रूप से संग्रहीत कर सकें।';

  @override
  String get restoreBackupConfirmTitle => 'पूर्ण बैकअप पुनर्स्थापित करें?';

  @override
  String get restoreBackupConfirmMessage =>
      'यह सभी वर्तमान टाइमटेबल, सामान्य शेड्यूल, सेटिंग और स्कूल साइटों को बदल देगा। API कुंजियां बैकअप से आयात नहीं होतीं; टाइमटेबल फिर से पार्स करने से पहले कुंजी दोबारा दर्ज करें।';

  @override
  String get restoreBackupConfirmAction => 'बैकअप पुनर्स्थापित करें';

  @override
  String get restoreBackupSuccessMessage =>
      'पूर्ण ऐप बैकअप पुनर्स्थापित हो गया। AI API कुंजियां दोबारा दर्ज करनी होंगी।';

  @override
  String get restoreBackupFailureMessage =>
      'पुनर्स्थापना विफल रही। बैकअप सामग्री जांचें और फिर कोशिश करें।';

  @override
  String get openSourceLicenses => 'ओपन-सोर्स लाइसेंस';

  @override
  String get openSourceLicensesDesc =>
      'Flutter डिपेंडेंसी और शामिल ऐप आइकन एसेट्स के लाइसेंस देखें।';

  @override
  String get checkForUpdates => 'अपडेट जाँचें';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String get microsoftStoreUpdates =>
      'अपडेट Microsoft Store द्वारा प्रबंधित किए जाते हैं';

  @override
  String get includePrereleaseUpdates => 'प्रीरिलीज़ अपडेट प्राप्त करें';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Alpha, Beta और RC संस्करण शामिल करें, जो अस्थिर हो सकते हैं। बंद होने पर केवल स्थिर संस्करण दिए जाते हैं।';

  @override
  String alreadyLatestVersion(Object version) {
    return 'आप पहले से नवीनतम संस्करण ($version) पर हैं';
  }

  @override
  String get currentVersionLabel => 'वर्तमान संस्करण';

  @override
  String get newVersionAvailable => 'अपडेट उपलब्ध है';

  @override
  String get latestVersionLabel => 'नवीनतम संस्करण';

  @override
  String get updateContentLabel => 'अपडेट विवरण';

  @override
  String get officialWebsite => 'आधिकारिक वेबसाइट';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'क्लाउड ड्राइव';

  @override
  String get ignoreThisVersion => 'इस संस्करण को अनदेखा करें';

  @override
  String get openUpdatesFailed => 'अपडेट लिंक खोलने में असमर्थ';

  @override
  String get updateCheckFailedTitle => 'अपडेट जाँच विफल';

  @override
  String get updateCheckFailedMessage =>
      'GitHub से नवीनतम संस्करण नहीं मिला। आप नीचे GitHub Releases खोल सकते हैं।';

  @override
  String get githubRepository => 'GitHub रिपॉज़िटरी';

  @override
  String get googlePlayStoreDesc => 'Google Play पर Sked देखें';

  @override
  String get openGooglePlayFailed => 'Google Play नहीं खुल सका';

  @override
  String get starSkedOnGithub => 'GitHub पर Sked को स्टार दें!';

  @override
  String get starSkedOnGithubDesc =>
      'प्रोजेक्ट रिपॉज़िटरी खोलें और Sked को स्टार दें';

  @override
  String get openGithubFailed => 'GitHub रिपॉज़िटरी लिंक खोलने में असमर्थ';

  @override
  String get openPrivacyPolicyFailed => 'गोपनीयता नीति का लिंक नहीं खुल सका';

  @override
  String get selectPeriodTimeSet => 'अवधि समय सेट चुनें';

  @override
  String get newItem => 'नया';

  @override
  String get editPeriodTimeSet => 'अवधि समय सेट संपादित करें';

  @override
  String get importTimetableFiles => 'टाइमटेबल आयात करें';

  @override
  String get importTimetableFilesDesc =>
      'एक या कई टाइमटेबल फ़ाइलों का समर्थन करता है।';

  @override
  String get importTimetableText => 'पाठ से टाइमटेबल आयात करें';

  @override
  String get importTimetableTextDesc =>
      'टाइमटेबल JSON सामग्री पेस्ट करें और आयात करें।';

  @override
  String get shareTimetableFiles => 'टाइमटेबल फ़ाइलें साझा करें';

  @override
  String get shareTimetableFilesDesc => 'पहले एक या अधिक टाइमटेबल चुनें।';

  @override
  String get saveTimetableFiles => 'टाइमटेबल फ़ाइलें सहेजें';

  @override
  String get saveTimetableFilesDesc => 'पहले एक या अधिक टाइमटेबल चुनें।';

  @override
  String get exportTimetableText => 'टाइमटेबल को पाठ के रूप में निर्यात करें';

  @override
  String get exportTimetableTextDesc =>
      'एक या अधिक टाइमटेबल चुनें, फिर JSON सामग्री कॉपी करें।';

  @override
  String get jsonContent => 'JSON सामग्री';

  @override
  String get pasteJsonContentHint =>
      'आयात करने के लिए JSON सामग्री पेस्ट करें।';

  @override
  String get jsonContentEmpty => 'पहले JSON सामग्री पेस्ट करें।';

  @override
  String get copyText => 'कॉपी करें';

  @override
  String get copiedToClipboard => 'क्लिपबोर्ड में कॉपी किया गया';

  @override
  String get share => 'साझा करें';

  @override
  String get selectTimetablesToExport => 'निर्यात करने के लिए टाइमटेबल चुनें';

  @override
  String get selectTimetablesToImport => 'आयात करने के लिए टाइमटेबल चुनें';

  @override
  String timetableCourseCount(int count) {
    return '$count कोर्स';
  }

  @override
  String get importAction => 'आयात करें';

  @override
  String get importTimetableDialogTitle => 'टाइमटेबल आयात करें';

  @override
  String get chooseImportMethod => 'आयात का तरीका चुनें।';

  @override
  String get importAsNewTimetable => 'नए टाइमटेबल के रूप में आयात करें';

  @override
  String get replaceCurrentTimetable => 'वर्तमान टाइमटेबल बदलें';

  @override
  String get importPeriodTimeSetDialogTitle => 'अवधि समय सेट आयात करें';

  @override
  String get importPeriodTimeSetDialogBody =>
      'इस फ़ाइल में शामिल अवधि समय सेट हैं। क्या आप इन्हें आयात करके संबद्ध करना चाहते हैं?';

  @override
  String get importBundledPeriodTimeSets => 'आयात करें और संबद्ध करें';

  @override
  String get discardBundledPeriodTimeSets => 'शामिल सेट छोड़ें';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'कोई मौजूदा अवधि समय सेट उपलब्ध नहीं है, इसलिए शामिल अवधि समय सेटों को छोड़ा नहीं जा सकता।';

  @override
  String savedToPath(Object path) {
    return '$path में सहेजा गया';
  }

  @override
  String get saveCancelled => 'सहेजना रद्द किया गया';

  @override
  String get fileSaveRestrictedTitle => 'फ़ाइल सहेजना सीमित है';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'सिस्टम फ़ाइल सहेज नहीं सका। आप फिर से कोशिश कर सकते हैं या इसकी जगह शेयरिंग का उपयोग कर सकते हैं।';

  @override
  String get retrySave => 'फिर से सहेजें';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'सिस्टम सेटिंग्स में फ़ाइल एक्सेस सक्षम करें, फिर वापस आकर दोबारा निर्यात करें।';

  @override
  String get openSettings => 'सेटिंग्स खोलें';

  @override
  String get browserDownloadRestrictedTitle => 'ब्राउज़र डाउनलोड सीमित है';

  @override
  String get browserDownloadRestrictedMessage =>
      'यह ब्राउज़र सीधे स्थानीय फ़ाइल में सहेजने का समर्थन नहीं करता। ब्राउज़र डाउनलोड अनुमतियाँ जाँचें या इसकी जगह फ़ाइल शेयरिंग का उपयोग करें।';

  @override
  String get switchToShare => 'इसके बजाय शेयरिंग उपयोग करें';

  @override
  String get fileSaveFailedTitle => 'फ़ाइल सहेजना विफल';

  @override
  String get fileSaveFailedWindowsMessage =>
      'वर्तमान पथ पर लिखा नहीं जा सका। लक्ष्य फ़ोल्डर संरक्षित हो सकता है, फ़ाइल उपयोग में हो सकती है, या पथ लिखने योग्य नहीं हो सकता।';

  @override
  String get fileSaveFailedGenericMessage =>
      'सिस्टम फ़ाइल सहेज नहीं सका। आप फिर से कोशिश कर सकते हैं, सिस्टम सेटिंग्स जाँच सकते हैं या इसकी जगह फ़ाइल शेयरिंग का उपयोग कर सकते हैं।';

  @override
  String get retryLater => 'बाद में फिर कोशिश करें';

  @override
  String get exportSwitchedToShare =>
      'निर्यात के लिए फ़ाइल शेयरिंग पर स्विच किया गया';

  @override
  String get saveFailedRetry =>
      'सहेजना विफल हुआ। कृपया बाद में फिर कोशिश करें।';

  @override
  String get periodTimesUnsavedExitTitle => 'बदलाव सहेजे नहीं गए';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'पीरियड के समय में किए गए नवीनतम बदलाव सहेजे नहीं जा सके। आप फिर कोशिश कर सकते हैं, संपादन जारी रख सकते हैं या बदलाव छोड़ सकते हैं।';

  @override
  String get periodTimesInvalidExitMessage =>
      'कुछ पीरियड के समय अमान्य हैं। सहेजने से पहले उन्हें ठीक करें या बदलाव छोड़कर बाहर निकलें।';

  @override
  String get discardChangesAndExit => 'बदलाव छोड़ें और बाहर निकलें';

  @override
  String get appInstanceBlockedTitle => 'Sked पहले से खुला है';

  @override
  String get appInstanceBlockedMessage =>
      'कोई दूसरी Sked विंडो या ब्राउज़र टैब आपके स्थानीय डेटा का उपयोग कर रहा है। उसे बंद करें, फिर दोबारा कोशिश करें।';

  @override
  String get appInstanceLeaseFailedTitle => 'स्थानीय डेटा उपलब्ध नहीं है';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked स्थानीय डेटा की विशेष पहुँच की पुष्टि नहीं कर सका। आपका डेटा न तो खोला गया और न ही बदला गया। स्टोरेज की पहुँच जाँचें, फिर दोबारा कोशिश करें।';

  @override
  String get savingChanges => 'बदलाव सेव किए जा रहे हैं...';

  @override
  String get showApiKey => 'API कुंजी दिखाएँ';

  @override
  String get hideApiKey => 'API कुंजी छिपाएँ';

  @override
  String get importFailedCheckContent =>
      'आयात विफल हुआ। कृपया फ़ाइल सामग्री जाँचें।';

  @override
  String get noImportableTimetables =>
      'आयात की गई फ़ाइल में कोई उपयोगी टाइमटेबल नहीं मिला।';

  @override
  String importedTimetablesCount(int count) {
    return '$count टाइमटेबल आयात किए गए';
  }

  @override
  String get periodTimesTitle => 'अवधि समय';

  @override
  String get importExport => 'आयात और निर्यात';

  @override
  String get importPeriodTemplate => 'अवधि टेम्पलेट आयात करें';

  @override
  String get importPeriodTemplateText => 'पाठ से अवधि टेम्पलेट आयात करें';

  @override
  String get sharePeriodTemplate => 'अवधि टेम्पलेट साझा करें';

  @override
  String get saveTemplateToFile => 'टेम्पलेट फ़ाइल में सहेजें';

  @override
  String get exportPeriodTemplateText =>
      'अवधि टेम्पलेट को पाठ के रूप में निर्यात करें';

  @override
  String get deletePeriodTimeSet => 'अवधि समय सेट हटाएँ';

  @override
  String get periodTimeSetName => 'अवधि समय सेट का नाम';

  @override
  String get addOnePeriod => 'अवधि जोड़ें';

  @override
  String periodNumberLabel(int index) {
    return 'अवधि $index';
  }

  @override
  String get deleteThisPeriod => 'इस अवधि को हटाएँ';

  @override
  String durationMinutes(int minutes) {
    return 'अवधि $minutes मिनट';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'पिछली से अंतर $minutes मिनट';
  }

  @override
  String get endTimeMustBeLater =>
      'समाप्ति समय प्रारंभ समय से बाद का होना चाहिए';

  @override
  String get periodOverlapPrevious => 'यह अवधि पिछली अवधि से ओवरलैप करती है';

  @override
  String get periodTimesSaved => 'अवधि समय सहेजे गए';

  @override
  String get deletePeriodTimeSetTitle => 'अवधि समय सेट हटाएँ';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return '\"$name\" हटाएँ?';
  }

  @override
  String get currentPeriodTimeSet => 'वर्तमान अवधि समय सेट';

  @override
  String importedPeriodTimesCount(int count) {
    return '$count अवधि समय आयात किए गए';
  }

  @override
  String get periodFilePermissionTitle => 'फ़ाइल अनुमति आवश्यक है';

  @override
  String get androidFilePermissionMessage =>
      'Android निर्यात के लिए फ़ाइल एक्सेस अनुमति चाहिए। सहेजना जारी रखने के लिए अनुमति दें।';

  @override
  String get reauthorize => 'फिर से अनुमति दें';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'अनुमति स्थायी रूप से अस्वीकृत';

  @override
  String get permissionSettingsExportMessage =>
      'सिस्टम सेटिंग्स में फ़ाइल एक्सेस सक्षम करें, फिर वापस आकर दोबारा निर्यात करें।';

  @override
  String get privacyPolicyTitle => 'गोपनीयता नीति';

  @override
  String get privacyPolicyEntryDesc =>
      'जानें कि ऐप स्थानीय संग्रहण, स्कूल-साइट कॉन्फ़िगरेशन, फ़ाइल आयात/निर्यात, वेबपेज पार्सिंग और बाहरी लिंक को कैसे संभालता है।';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'स्वीकृत संस्करण: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked एक स्थानीय-प्रथम समय सारिणी उपकरण है। समय सारिणी, अवधि-समय सेट और स्कूल-साइट कॉन्फ़िगरेशन केवल आपके डिवाइस या ब्राउज़र में संग्रहीत होते हैं और कभी भी स्वचालित रूप से अपलोड नहीं होते। ऐप केवल तभी डेटा संसाधित करता है जब आप स्पष्ट रूप से आयात, वेबपेज पार्सिंग, साझाकरण या बाहरी लिंक खोलने जैसी कार्रवाइयाँ शुरू करते हैं। पूर्ण गोपनीयता नीति ऑनलाइन उपलब्ध है।';

  @override
  String get privacyPolicyLocalStorageTitle => 'स्थानीय संग्रहण';

  @override
  String get privacyPolicyLocalStorageBody =>
      'मूल प्लेटफ़ॉर्म पर Sked टाइमटेबल डेटा, सामान्य शेड्यूल, संबंधित सेटिंग्स और संपादन योग्य स्कूल-साइट कॉन्फ़िगरेशन को ऑपरेटिंग सिस्टम के ऐप्लिकेशन-सपोर्ट फ़ोल्डर में रखता है; ब्राउज़र संस्करण ब्राउज़र स्टोरेज का उपयोग करते हैं। पुराने संस्करणों द्वारा उपयोगकर्ता के Documents फ़ोल्डर में लिखी गई फ़ाइलें वहीं रहती हैं, लेकिन उन्हें अपने आप पढ़ा या माइग्रेट नहीं किया जाता। उस डेटा को बनाए रखने के लिए, अपग्रेड से पहले पुराने संस्करण से पूरा ऐप बैकअप निर्यात करें और बाद में उसे पुनर्स्थापित करें। AI API सेटिंग्स स्थानीय रूप से सहेजी जाती हैं; उपलब्ध होने पर कस्टम API कुंजी प्लेटफ़ॉर्म के सुरक्षित स्टोरेज में रखी जाती है। पूरे ऐप बैकअप में कस्टम API कुंजी शामिल नहीं होती। ऐप यह स्थानीय डेटा अपने आप डेवलपर-नियंत्रित सर्वर पर अपलोड नहीं करता।';

  @override
  String get privacyPolicyImportExportTitle => 'आयात और निर्यात';

  @override
  String get privacyPolicyImportExportBody =>
      'ऐप टाइमटेबल JSON फ़ाइलें, स्कूल-साइट JSON फ़ाइलें और अवधि-टेम्पलेट फ़ाइलें तभी पढ़ता या लिखता है जब आप स्पष्ट रूप से कोई फ़ाइल चुनते हैं या निर्यात क्रिया शुरू करते हैं। इन फ़ाइलों का आयात एक स्थानीय क्रिया है, जब तक कि आप वेबपेज पार्सिंग भी न चुनें। कस्टम मॉडल सूची प्राप्त करना भी एक स्पष्ट नेटवर्क क्रिया है और यह केवल उसी कस्टम एंडपॉइंट से संपर्क करता है जिसे आपने कॉन्फ़िगर किया है।';

  @override
  String get privacyPolicySharingTitle => 'साझाकरण';

  @override
  String get privacyPolicySharingBody =>
      'जब आप स्पष्ट रूप से शेयरिंग का उपयोग करते हैं, तो ऐप निर्यात की गई फ़ाइल को सिस्टम शेयर शीट या आपके चुने गए लक्ष्य ऐप को भेजता है। उसके बाद उस फ़ाइल को कैसे संभाला जाता है, यह आपके चुने गए लक्ष्य ऐप या सेवा पर निर्भर करता है।';

  @override
  String get privacyPolicyExternalLinksTitle => 'बाहरी लिंक';

  @override
  String get privacyPolicyExternalLinksBody =>
      'जब आप GitHub रिपॉज़िटरी जैसे बाहरी लिंक खोलते हैं, तो ऐप उस क्रिया को आपके ब्राउज़र या किसी अन्य बाहरी एप्लिकेशन को सौंप देता है। उसके बाद डेटा प्रबंधन उस तृतीय पक्ष द्वारा नियंत्रित होता है जिसे आप खोलते हैं।';

  @override
  String get privacyPolicyNoCollectionTitle => 'ऐप क्या एकत्र नहीं करता';

  @override
  String get privacyPolicyNoCollectionBody =>
      'ऐप को Sked खाते की आवश्यकता नहीं है और यह एनालिटिक्स, विज्ञापन पहचानकर्ता या क्लाउड बैकअप सक्षम नहीं करता। यह स्कूल खाते के पासवर्ड एकत्र करने के लिए अलग फ़ील्ड भी प्रदान नहीं करता। यदि आप ऐप के अंदर किसी स्कूल वेबसाइट में साइन इन करते हैं, तो वह इंटरैक्शन उसी स्कूल पेज पर होता है जिसे आपने खोला है।';

  @override
  String get privacyPolicyFutureFeatureTitle => 'वेबपेज पार्सिंग';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'जब आप स्कूल वेबपेज आयात का उपयोग करते हैं या पेस्ट किए गए समय-सारणी पाठ / HTML को पार्स करते हैं, तो ऐप पहले सामग्री को स्थानीय रूप से तैयार और साफ करता है, फिर सबमिट किया गया समय-सारणी पाठ, पेज पाठ या HTML सामग्री, वैकल्पिक पेज शीर्षक और URL, ऐप की वर्तमान भाषा और पार्सर प्रॉम्प्ट सामग्री आपके कॉन्फ़िगर किए गए OpenAI-संगत एंडपॉइंट पर भेजता है। मॉडल सूची लाने पर भी वही एंडपॉइंट अनुरोधित होता है। Sked कोई अंतर्निहित पार्सर एंडपॉइंट प्रदान नहीं करता और पार्सिंग अनुरोधों को डेवलपर-नियंत्रित समय-सारणी पार्सर बैकएंड पर नहीं भेजता। कस्टम एंडपॉइंट और कोई भी अपस्ट्रीम सेवाएँ आपके चुने हुए सेवा प्रदाता के नियमों के अनुसार डेटा को सहेज, आगे भेज, सीमित, हटा या अन्यथा संसाधित कर सकती हैं। यदि आप http:// Base URL का उपयोग करते हैं, तो इसे केवल विश्वसनीय डिवाइस, विश्वसनीय नेटवर्क और विश्वसनीय एंडपॉइंट सेवाओं पर उपयोग करें, क्योंकि सामग्री और API कुंजियाँ ट्रांसपोर्ट एन्क्रिप्शन से सुरक्षित नहीं हो सकती हैं।';

  @override
  String get privacyPolicyUpdatesTitle => 'नीति अपडेट';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'वर्तमान गोपनीयता नीति संस्करण $version है। यदि किसी बाद के संस्करण में डेटा प्रबंधन का तरीका बदलता है, तो ऐप आपसे अद्यतन नीति को फिर से पढ़ने और स्वीकार करने के लिए कह सकता है।';
  }

  @override
  String get privacyGateTitle =>
      'ऐप का उपयोग करने से पहले कृपया गोपनीयता नीति से सहमत हों';

  @override
  String get privacyGateSummaryStorage =>
      'टाइमटेबल, अवधि-समय सेट और स्कूल-साइट कॉन्फ़िगरेशन केवल स्थानीय रूप से संग्रहीत होते हैं और अपने-आप किसी डेवलपर सर्वर पर अपलोड नहीं होते।';

  @override
  String get privacyGateSummaryImportExport =>
      'आयात, निर्यात और शेयरिंग केवल तभी होते हैं जब आप उन्हें स्पष्ट रूप से शुरू करते हैं; वेबपेज पार्सिंग केवल वही संपीड़ित सामग्री आपके कॉन्फ़िगर किए गए पार्सिंग एंडपॉइंट पर भेजती है जो आप जमा करते हैं, और सहेजने से पहले आप पार्स किए गए टाइमटेबल की समीक्षा कर सकते हैं।';

  @override
  String get privacyGateSummaryUpdates =>
      'यदि किसी बाद के संस्करण में डेटा प्रबंधन का तरीका बदलता है, तो ऐप आपसे अद्यतन गोपनीयता नीति की फिर से समीक्षा करने के लिए कह सकता है।';

  @override
  String get schoolWebImportEntry => 'स्कूल वेबपेज से आयात करें';

  @override
  String get schoolWebImportEntryDesc =>
      'स्कूल साइट के वर्तमान टाइमटेबल पेज को आयात करें।';

  @override
  String get schoolSitesManageEntry => 'स्कूल साइट प्रबंधित करें';

  @override
  String get schoolSitesManageEntryDesc =>
      'स्कूल लॉगिन URL जोड़ें, संपादित करें और हटाएँ, साथ में JSON आयात और निर्यात।';

  @override
  String get schoolSitesPageTitle => 'स्कूल साइट प्रबंधन';

  @override
  String get schoolSitesImportJson => 'स्कूल JSON आयात करें';

  @override
  String get schoolSitesShareJson => 'स्कूल JSON साझा करें';

  @override
  String get schoolSitesSaveJson => 'स्कूल JSON सहेजें';

  @override
  String get schoolSitesSaved => 'स्कूल साइटें सहेजी गईं';

  @override
  String get schoolSitesImported => 'स्कूल साइटें आयात की गईं';

  @override
  String get schoolSitesImportPreviewTitle => 'स्कूल-साइट आयात की समीक्षा करें';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount मान्य साइटें, $invalidCount अमान्य प्रविष्टियाँ।';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'फ़ाइल में स्कूल-साइटों की सूची खाली है।';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'प्रविष्टि $position अमान्य है और छोड़ दी जाएगी।';
  }

  @override
  String get schoolSitesImportMerge => 'मिलाएँ';

  @override
  String get schoolSitesImportReplace => 'बदलें';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'मौजूदा स्कूल साइटें बदलें?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'इससे $currentCount मौजूदा साइटें हटेंगी और $importedCount आयात की गई साइटें सहेजी जाएँगी। इसे पूर्ववत नहीं किया जा सकता।';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'स्कूल-साइट डेटा को पुनर्प्राप्त करना होगा';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked स्कूल-साइट फ़ाइल या उसका बैकअप नहीं पढ़ सका। लिखना रोकने से पहले सुरक्षित प्रतियाँ बनाई गईं।';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'स्कूल-साइट स्टोरेज उपलब्ध नहीं है';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked अभी स्कूल-साइट स्टोरेज तक नहीं पहुँच सकता। स्टोरेज की पहुँच या डिवाइस की उपलब्धता जाँचने के बाद फिर कोशिश करें। मौजूदा साइट डेटा अधिलेखित नहीं होगा।';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'पुनर्प्राप्ति फ़ाइलें या प्रभावित स्टोरेज स्थान नीचे दिए गए हैं। साइट सूची पुनर्प्राप्त होने तक फ़ाइलें न बदलें।';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'बिना स्कूल साइटों के शुरू करें';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'स्कूल-साइटों की खाली सूची से शुरू करें?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'सुरक्षित प्रतियाँ रखी जाएँगी, लेकिन Sked एक नई खाली स्कूल-साइट फ़ाइल बनाएगा। तभी जारी रखें जब आप पहले पुनर्प्राप्ति की कोशिश नहीं करना चाहते।';

  @override
  String get schoolSitesEmpty => 'अभी तक कोई स्कूल साइट कॉन्फ़िगरेशन नहीं है।';

  @override
  String get schoolSitesNameLabel => 'स्कूल का नाम';

  @override
  String get schoolSitesLoginUrlLabel => 'लॉगिन URL';

  @override
  String get schoolSitesAdd => 'स्कूल जोड़ें';

  @override
  String get schoolSitesEdit => 'स्कूल संपादित करें';

  @override
  String get schoolSitesDeleteTitle => 'स्कूल हटाएँ';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return '\"$name\" हटाएँ?';
  }

  @override
  String get schoolSitesFormInvalid => 'पहले स्कूल का नाम और लॉगिन URL भरें।';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'टाइमटेबल पेज की सामग्री पेस्ट करके आयात करें';

  @override
  String get schoolHtmlImportEntryDesc =>
      'टाइमटेबल जानकारी वाली स्रोत कोड या कच्ची पेज सामग्री मैन्युअल रूप से पेस्ट करें।';

  @override
  String get schoolHtmlImportPageTitle => 'पेज सामग्री से टाइमटेबल पार्स करें';

  @override
  String get schoolHtmlImportUrlLabel => 'स्रोत URL (वैकल्पिक)';

  @override
  String get schoolHtmlImportTitleLabel => 'पेज शीर्षक (वैकल्पिक)';

  @override
  String get schoolHtmlImportHtmlLabel => 'पेज सामग्री';

  @override
  String get schoolHtmlImportHtmlHint =>
      'टाइमटेबल जानकारी वाली स्रोत कोड या कच्ची पेज सामग्री यहाँ पेस्ट करें।';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'केवल HTML ही नहीं, टाइमटेबल जानकारी वाली कोई भी सामग्री पार्स और आयात की जा सकती है।';

  @override
  String get schoolHtmlImportCompress => 'सामग्री तैयार करें';

  @override
  String get schoolHtmlImportCompressed => 'सामग्री तैयार है';

  @override
  String get schoolHtmlImportCompressFirst => 'पहले सामग्री तैयार करें।';

  @override
  String get schoolHtmlImportSubmit => 'पार्स करें और आयात करें';

  @override
  String get schoolImportContentTruncated =>
      'यह पेज सुरक्षित आयात सीमा तक पहुँच गया है। विश्लेषण के लिए केवल कैप्चर किया गया भाग भेजा जाएगा।';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'पार्सिंग में समय लग सकता है। कृपया प्रतीक्षा करें।';

  @override
  String get schoolHtmlImportEmpty => 'पहले पेज HTML पेस्ट करें।';

  @override
  String get schoolHtmlImportReturnToWebPage => 'वेबपेज पर वापस जाएँ';

  @override
  String get schoolWebImportPageTitle => 'स्कूल वेबपेज आयात';

  @override
  String get schoolWebImportPreview => 'आयात पूर्वावलोकन';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count कोर्स';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count अवधि';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'पेज शीर्षक';

  @override
  String get schoolWebImportParserUsed => 'पार्सर';

  @override
  String get schoolWebImportWarnings => 'आयात नोट्स';

  @override
  String get schoolWebImportParserDetails => 'पार्सिंग विवरण';

  @override
  String get schoolWebImportExpandParserDetails => 'पार्सिंग विवरण फैलाएं';

  @override
  String get schoolWebImportCollapseParserDetails => 'पार्सिंग विवरण समेटें';

  @override
  String get schoolWebImportOpenPageHint =>
      'ऐप के भीतर स्कूल साइट में साइन इन करें, फिर मैन्युअल रूप से टाइमटेबल पेज पर जाएँ।';

  @override
  String get schoolWebImportConfigMissing =>
      'कस्टम पार्सर का कॉन्फ़िगरेशन अधूरा है। पहले बेस URL, API कुंजी और मॉडल भरें।';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'यह प्लेटफ़ॉर्म अभी एम्बेडेड वेब लॉगिन का समर्थन नहीं करता। कृपया WebView समर्थन वाले प्लेटफ़ॉर्म का उपयोग करें।';

  @override
  String get schoolWebImportSelectSchool => 'स्कूल चुनें';

  @override
  String get schoolWebImportNoSchools =>
      'कोई स्कूल कॉन्फ़िगरेशन उपलब्ध नहीं है। पहले school_sites.json जाँचें।';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'स्कूल कॉन्फ़िगरेशन लोड नहीं हो सका। JSON फ़ाइल फ़ॉर्मेट जाँचें।';

  @override
  String get schoolWebImportImportCurrentPage => 'वर्तमान पेज आयात करें';

  @override
  String get schoolWebImportLoadingPage => 'पेज लोड हो रहा है…';

  @override
  String get schoolWebImportParsing => 'वर्तमान पेज पार्स हो रहा है…';

  @override
  String get schoolWebImportLoadFailed =>
      'पेज लोड विफल हुआ। कृपया रीफ़्रेश करें या बाद में फिर प्रयास करें।';

  @override
  String get schoolWebImportUnknownOrigin => 'अज्ञात साइट';

  @override
  String get schoolWebImportExitTitle => 'ब्राउज़र से बाहर निकलें?';

  @override
  String get schoolWebImportExitMessage =>
      'पेज बंद हो जाएगा। जो कुछ आपने अभी तक आयात नहीं किया है वह खो जाएगा।';

  @override
  String get schoolWebImportExitConfirm => 'बाहर निकलें';

  @override
  String get schoolWebImportEmptyPage =>
      'वर्तमान पेज सामग्री खाली है और अभी आयात नहीं की जा सकती।';

  @override
  String get schoolWebImportSuccess => 'वेब टाइमटेबल आयात किया गया';

  @override
  String get schoolImportParserSettingsTitle => 'समय-सारणी पार्सिंग API';

  @override
  String get schoolImportParserSettingsDesc =>
      'समय-सारणी आयात के लिए OpenAI-संगत API कॉन्फ़िगर करें। यह चैट सहायक की सेटिंग नहीं है।';

  @override
  String get schoolImportParserSourceTitle => 'पार्सर स्रोत';

  @override
  String get schoolImportParserSourceCustomOpenAi => 'कस्टम OpenAI-compatible';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi => 'कस्टम OpenAI-compatible पार्सर';

  @override
  String get schoolImportParserCustomPromptTitle => 'कस्टम प्रॉम्प्ट';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'यहाँ अंतर्निहित पार्सर प्रॉम्प्ट संपादित करें। बदलाव केवल कस्टम OpenAI-compatible पार्सर को प्रभावित करेंगे।';

  @override
  String get schoolImportParserCustomPromptHint =>
      'डिफ़ॉल्ट रूप से यहाँ अंतर्निहित प्रॉम्प्ट लोड होता है। अंतर्निहित संस्करण पर लौटने के लिए इसे साफ़ करें।';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'डिफ़ॉल्ट प्रॉम्प्ट रीसेट करें';

  @override
  String get schoolImportParserBaseUrl => 'बेस URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL होस्ट वाली HTTP या HTTPS URL होनी चाहिए.';

  @override
  String get schoolImportParserApiKey => 'API कुंजी';

  @override
  String get schoolImportParserModel => 'मॉडल';

  @override
  String get schoolImportParserFetchModels => 'मॉडल सूची प्राप्त करें';

  @override
  String get schoolImportParserFetchingModels =>
      'मॉडल प्राप्त किए जा रहे हैं...';

  @override
  String get schoolImportParserNoModelsFound =>
      'एंडपॉइंट ने कोई मॉडल नहीं लौटाया।';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'मॉडल प्राप्त नहीं किए जा सके। एंडपॉइंट जांचें और फिर कोशिश करें।';

  @override
  String schoolImportParserModelsFetched(int count) {
    return '$count मॉडल प्राप्त हुए';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'उपलब्ध होने पर कस्टम API कुंजी प्लेटफ़ॉर्म के सुरक्षित स्टोरेज में रखी जाती है। कस्टम पार्सर के क्रेडेंशियल और HTTP एंडपॉइंट केवल विश्वसनीय डिवाइस, ब्राउज़र और नेटवर्क पर उपयोग करें।';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'क्या बिना एन्क्रिप्शन वाले HTTP एंडपॉइंट का उपयोग करें?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'API कुंजी और समय-सारणी की सामग्री को भेजे जाते समय पढ़ा या बदला जा सकता है। केवल तभी जारी रखें जब आप इस डिवाइस, नेटवर्क और एंडपॉइंट पर भरोसा करते हों। यह अनुमति Sked बंद करने तक मान्य रहेगी।';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'कस्टम पार्सर कॉन्फ़िगरेशन अधूरी है। पहले Base URL, API key और मॉडल भरें।';

  @override
  String get clearAppData => 'डेटा मिटाएँ';

  @override
  String get clearAppDataDesc =>
      'Sked का सारा स्थानीय डेटा स्थायी रूप से मिटाएँ और ऐप से बाहर निकलें';

  @override
  String get clearAppDataConfirmTitle => 'Sked का सारा डेटा मिटाएँ?';

  @override
  String get clearAppDataConfirmMessage =>
      'इससे टाइमटेबल, शेड्यूल, सेटिंग्स, स्कूल साइटें, स्थानीय बैकअप, पुनर्प्राप्ति प्रतियाँ और AI API कुंजी स्थायी रूप से मिट जाएँगे, फिर Sked बंद हो जाएगा। अन्य स्थानों पर निर्यात की गई फ़ाइलें नहीं मिटेंगी। इसे पूर्ववत नहीं किया जा सकता।';

  @override
  String get clearAppDataAction => 'डेटा मिटाएँ और बाहर निकलें';

  @override
  String get clearAppDataFailed =>
      'सारा स्थानीय डेटा नहीं मिट सका। दोबारा कोशिश करने के लिए Sked खुला रहेगा।';

  @override
  String get clearAppDataExitFailed =>
      'आपका स्थानीय डेटा मिट गया, लेकिन Sked बंद नहीं हो सका। दोबारा उपयोग करने से पहले ऐप को स्वयं बंद करें।';

  @override
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'पार्सर: कस्टम ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'पूरी गोपनीयता नीति देखें';

  @override
  String get privacyAgreeAndContinue => 'सहमत हूँ और जारी रखें';

  @override
  String get privacyDecline => 'अस्वीकार करें';

  @override
  String get privacyDeclineWebHint =>
      'यह ब्राउज़र वातावरण ऐप को आपके लिए पेज बंद करने की अनुमति नहीं देता। यदि आप सहमत नहीं हैं, तो कृपया यह टैब या विंडो स्वयं बंद करें।';

  @override
  String get defaultPeriodTimeSetName => 'डिफ़ॉल्ट अवधियाँ';

  @override
  String get periodTimeSetFallbackName => 'अवधि समय';

  @override
  String get untitledTimetableName => 'बिना शीर्षक टाइमटेबल';

  @override
  String get newTimetableName => 'नया टाइमटेबल';

  @override
  String get newPeriodTimeSetName => 'नया अवधि समय सेट';

  @override
  String get emptyTimetableName => 'खाली टाइमटेबल';

  @override
  String importedPeriodTimeSetName(Object name) {
    return '$name अवधियाँ';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'आयात फ़ाइल प्रकार मेल नहीं खाता।';

  @override
  String get importFileVersionUnsupportedMessage =>
      'यह आयात फ़ाइल संस्करण अभी समर्थित नहीं है।';

  @override
  String get noPeriodTimesInImportMessage =>
      'आयात फ़ाइल में कोई अवधि समय नहीं मिला।';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'कृपया कम से कम एक टाइमटेबल चुनें।';

  @override
  String get noExportableTimetableMessage =>
      'निर्यात के लिए कोई टाइमटेबल उपलब्ध नहीं है।';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'वर्तमान टाइमटेबल बदलने के लिए केवल एक टाइमटेबल का चयन समर्थित है।';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'बदलने के लिए कोई वर्तमान टाइमटेबल नहीं है।';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'यह अवधि समय सेट अभी भी $count टाइमटेबल में उपयोग हो रहा है। हटाने से पहले उन्हें पुनः असाइन करें।';
  }

  @override
  String get weekdayMonday => 'सोमवार';

  @override
  String get weekdayTuesday => 'मंगलवार';

  @override
  String get weekdayWednesday => 'बुधवार';

  @override
  String get weekdayThursday => 'गुरुवार';

  @override
  String get weekdayFriday => 'शुक्रवार';

  @override
  String get weekdaySaturday => 'शनिवार';

  @override
  String get weekdaySunday => 'रविवार';

  @override
  String get weekdayShortMonday => 'सोम';

  @override
  String get weekdayShortTuesday => 'मंगल';

  @override
  String get weekdayShortWednesday => 'बुध';

  @override
  String get weekdayShortThursday => 'गुरु';

  @override
  String get weekdayShortFriday => 'शुक्र';

  @override
  String get weekdayShortSaturday => 'शनि';

  @override
  String get weekdayShortSunday => 'रवि';

  @override
  String get monthJanuary => 'जन';

  @override
  String get monthFebruary => 'फ़र';

  @override
  String get monthMarch => 'मार्च';

  @override
  String get monthApril => 'अप्रै';

  @override
  String get monthMay => 'मई';

  @override
  String get monthJune => 'जून';

  @override
  String get monthJuly => 'जुल';

  @override
  String get monthAugust => 'अग';

  @override
  String get monthSeptember => 'सित';

  @override
  String get monthOctober => 'अक्टू';

  @override
  String get monthNovember => 'नव';

  @override
  String get monthDecember => 'दिस';

  @override
  String get semesterWeeksWholeTerm => 'पूरा सेमेस्टर';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'सप्ताह $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'सप्ताह $value';
  }

  @override
  String get generalSchedule => 'सामान्य शेड्यूल';

  @override
  String get studentTimetable => 'छात्र टाइमटेबल';

  @override
  String get firstLaunchTitle => 'अपना प्रारंभिक मोड चुनें';

  @override
  String get firstLaunchSubtitle =>
      'जिस कार्यक्षेत्र का आप सबसे अधिक उपयोग करते हैं उसे चुनें। आप बाद में मोड बदल सकते हैं।';

  @override
  String get firstLaunchStudentDesc =>
      'टाइमटेबल, कोर्स, सप्ताह, पीरियड समय और आयात प्रबंधित करें।';

  @override
  String get firstLaunchGeneralDesc =>
      'श्रेणियाँ, ईवेंट, रिमाइंडर और JSON / ICS डेटा प्रबंधित करें।';

  @override
  String get firstLaunchStartStudent => 'टाइमटेबल से शुरू करें';

  @override
  String get firstLaunchStartGeneral => 'शेड्यूल से शुरू करें';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'शुरुआती कार्यक्षेत्र चुनकर आप पुष्टि करते हैं कि आपने ';

  @override
  String get firstLaunchPrivacyConsentLink => 'गोपनीयता नीति';

  @override
  String get firstLaunchPrivacyConsentAfter => ' पढ़ ली है और उससे सहमत हैं।';

  @override
  String get switchMode => 'मोड बदलें';

  @override
  String get generalScheduleComingSoon => 'सामान्य शेड्यूल जल्द आ रहा है';

  @override
  String get switchToStudentTimetable => 'छात्र टाइमटेबल पर जाएँ';

  @override
  String get mySchedule => 'मेरा शेड्यूल';

  @override
  String get today => 'आज';

  @override
  String get addEvent => 'इवेंट जोड़ें';

  @override
  String get editEvent => 'इवेंट संपादित करें';

  @override
  String get eventTitle => 'शीर्षक';

  @override
  String get eventTitleRequired => 'शीर्षक आवश्यक है';

  @override
  String get eventStartTime => 'शुरू होने का समय';

  @override
  String get eventEndTime => 'समाप्त होने का समय';

  @override
  String get eventDate => 'तारीख';

  @override
  String get eventTime => 'समय';

  @override
  String get eventNotes => 'नोट्स';

  @override
  String get eventColor => 'रंग';

  @override
  String get eventRecurrence => 'दोहराएँ';

  @override
  String get recurrenceNone => 'नहीं दोहराता';

  @override
  String get recurrenceWeekly => 'हर सप्ताह';

  @override
  String get recurrenceEndDate => 'समाप्ति की तारीख';

  @override
  String get recurrenceNoEndDate => 'कोई समाप्ति तारीख नहीं';

  @override
  String get recurrenceSetEndDate => 'तय करें';

  @override
  String get recurrenceChangeEndDate => 'बदलें';

  @override
  String get repeatsWeekly => 'हर सप्ताह दोहराता है';

  @override
  String recurrenceUntil(Object date) {
    return '$date तक';
  }

  @override
  String get switchToGeneralSchedule => 'सामान्य शेड्यूल पर जाएँ';

  @override
  String get generalDisplaySettings => 'सामान्य प्रदर्शन सेटिंग्स';

  @override
  String get generalDisplaySettingsDesc =>
      'दृश्य, टूलबार, तारीख प्रारूप और तुरंत जोड़ना';

  @override
  String get closePopupOnOutsideTap => 'बाहर टैप करने पर पॉपअप बंद करें';

  @override
  String get showGridLines => 'ग्रिड की रेखाएँ दिखाएँ';

  @override
  String get generalScheduleImportExport => 'श्रेणियों का आयात और निर्यात';

  @override
  String get generalScheduleImportExportDesc =>
      'शेड्यूल की श्रेणियाँ आयात या साझा करें';

  @override
  String get importGeneralSchedules => 'श्रेणियाँ आयात करें';

  @override
  String get importGeneralSchedulesDesc => 'JSON फ़ाइल से श्रेणियाँ पढ़ें';

  @override
  String get shareGeneralSchedules => 'श्रेणियाँ साझा करें';

  @override
  String get shareGeneralSchedulesDesc =>
      'श्रेणियाँ JSON फ़ाइल के रूप में साझा करें';

  @override
  String get saveGeneralSchedules => 'श्रेणियाँ सहेजें';

  @override
  String get saveGeneralSchedulesDesc =>
      'श्रेणियाँ JSON फ़ाइल के रूप में सहेजें';

  @override
  String get selectSchedulesToExport => 'निर्यात करने के लिए श्रेणियाँ चुनें';

  @override
  String get selectSchedulesToImport => 'आयात करने के लिए श्रेणियाँ चुनें';

  @override
  String generalScheduleEventCount(int count) {
    return 'इवेंट: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'आयात की गई श्रेणियाँ: $count';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'आयात को नई श्रेणी के रूप में जोड़ें या मौजूदा श्रेणी बदलें?';

  @override
  String get addAsNewSchedule => 'नई श्रेणी के रूप में जोड़ें';

  @override
  String get selectAtLeastOneScheduleMessage => 'कम से कम एक श्रेणी चुनें।';

  @override
  String get noExportableScheduleMessage =>
      'निर्यात करने के लिए कोई श्रेणी नहीं है।';

  @override
  String get noSchedulesInImportMessage => 'आयात फ़ाइल में कोई श्रेणी नहीं है।';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'बदलने के लिए आयात की गई केवल एक श्रेणी चुनें।';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'बदलने के लिए चुनी गई श्रेणी उपलब्ध नहीं है।';

  @override
  String get calendars => 'श्रेणियाँ';

  @override
  String get calendar => 'श्रेणी';

  @override
  String get viewWeek => 'सप्ताह';

  @override
  String get viewDay => 'दिन';

  @override
  String get viewList => 'सूची';

  @override
  String get viewMonth => 'महीना';

  @override
  String visibleCategoryCount(int count) {
    return '$count श्रेणियाँ';
  }

  @override
  String get noVisibleCategories => 'कोई श्रेणी दिखाई नहीं दे रही';

  @override
  String get selectCategoryToReplace => 'बदलने के लिए श्रेणी चुनें';

  @override
  String get replaceCategory => 'श्रेणी बदलें';

  @override
  String get deleteEventTitle => 'इवेंट हटाएँ';

  @override
  String get deleteEventConfirmation =>
      'यह इवेंट स्थायी रूप से हटा दिया जाएगा।';

  @override
  String get deleteRecurringEventTitle => 'दोहराया जाने वाला इवेंट हटाएँ';

  @override
  String get eventDuplicated => 'इवेंट की प्रतिलिपि बनाई गई';

  @override
  String get searchEvents => 'इवेंट खोजें';

  @override
  String get clearSearch => 'खोज साफ़ करें';

  @override
  String get filterByColor => 'रंग के अनुसार फ़िल्टर करें';

  @override
  String get allColors => 'सभी रंग';

  @override
  String upcomingEventsCount(int count) {
    return 'आगामी: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'बीते हुए: $count';
  }

  @override
  String get allDay => 'पूरे दिन';

  @override
  String get collapseAllDayTimeline => 'पूरे दिन के इवेंट समेटें';

  @override
  String get expandAllDayTimeline => 'पूरे दिन के इवेंट खोलें';

  @override
  String allDayEventsCount(int count) {
    return 'पूरे दिन के $count इवेंट';
  }

  @override
  String moreEvents(int count) {
    return '+$count और';
  }

  @override
  String get noMatchingEvents => 'कोई मेल खाता इवेंट नहीं';

  @override
  String get noUpcomingEvents => 'कोई आगामी इवेंट नहीं';

  @override
  String get addCalendar => 'श्रेणी जोड़ें';

  @override
  String get newCalendar => 'नई श्रेणी';

  @override
  String get hideCalendar => 'श्रेणी छिपाएँ';

  @override
  String get showCalendar => 'श्रेणी दिखाएँ';

  @override
  String get rename => 'नाम बदलें';

  @override
  String get renameCalendar => 'श्रेणी का नाम बदलें';

  @override
  String get name => 'नाम';

  @override
  String get deleteCalendar => 'श्रेणी हटाएँ';

  @override
  String deleteCalendarMessage(Object name) {
    return '\"$name\" हटाएँ?';
  }

  @override
  String get deleteThisOccurrence => 'केवल यह आवृत्ति हटाएँ';

  @override
  String get deleteFutureOccurrences => 'इसे और बाद की आवृत्तियाँ हटाएँ';

  @override
  String get deleteAllOccurrences => 'पूरी शृंखला हटाएँ';

  @override
  String get duplicateEvent => 'प्रतिलिपि बनाएँ';

  @override
  String get repeatsDaily => 'हर दिन दोहराता है';

  @override
  String get repeatsMonthly => 'हर महीने दोहराता है';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'हर $interval $unit में दोहराता है';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count बार';
  }

  @override
  String get recurrenceDaily => 'हर दिन';

  @override
  String get recurrenceMonthly => 'हर महीने';

  @override
  String get recurrenceCustom => 'कस्टम';

  @override
  String get recurrenceEvery => 'हर';

  @override
  String get recurrenceUnit => 'इकाई';

  @override
  String get recurrenceDays => 'दिन';

  @override
  String get recurrenceWeeks => 'सप्ताह';

  @override
  String get recurrenceMonths => 'महीने';

  @override
  String get recurrenceRepeatCount => 'दोहराव की संख्या';

  @override
  String get recurrenceNoLimit => 'कोई सीमा नहीं';

  @override
  String get recurrencePositiveNumber => 'धनात्मक संख्या दर्ज करें';

  @override
  String get clearEndDate => 'समाप्ति की तारीख हटाएँ';

  @override
  String get pickDate => 'तारीख चुनें';

  @override
  String get pickTime => 'समय चुनें';

  @override
  String get reminder => 'ऐप के भीतर रिमाइंडर';

  @override
  String get reminderAtStart => 'शुरू होने पर';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes मिनट पहले';
  }

  @override
  String get reminderHourBefore => '1 घंटा पहले';

  @override
  String get reminderDayBefore => '1 दिन पहले';

  @override
  String get markReminderHandled => 'निपटाया गया चिह्नित करें';

  @override
  String get restoreReminder => 'ऐप के भीतर रिमाइंडर बहाल करें';

  @override
  String get reminderHandled => 'ऐप का रिमाइंडर निपटाया गया चिह्नित किया';

  @override
  String get reminderRestored => 'ऐप का रिमाइंडर बहाल किया गया';

  @override
  String get reminderUpcoming => 'आगामी';

  @override
  String get reminderOverdue => 'समय बीत गया';

  @override
  String get generalFitWeekColumnsToWidth =>
      'सप्ताह दृश्य को स्क्रीन में फ़िट करें';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'कॉम्पैक्ट लेआउट में पूरा सप्ताह दिखाएँ। क्षैतिज स्क्रॉलिंग के लिए बंद करें। 7 दिनों से अधिक की कस्टम अवधियों में स्क्रॉलिंग जारी रहती है।';

  @override
  String get showWeekends => 'सप्ताहांत दिखाएँ';

  @override
  String get startHour => 'शुरू होने का घंटा';

  @override
  String get endHour => 'समाप्त होने का घंटा';

  @override
  String get timeGridDensity => 'समय ग्रिड का घनत्व';

  @override
  String get timeGridHourHeight => 'घंटे की पंक्ति की ऊँचाई';

  @override
  String get timeGridHourHeightHint =>
      'दिन और सप्ताह के दृश्यों का ऊर्ध्वाधर पैमाना बदलता है, लेकिन 15, 30 या 60 मिनट का ग्रिड अंतराल नहीं बदलता।';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'JSON फ़ाइल आयात करें';

  @override
  String get pasteJson => 'JSON चिपकाएँ';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'कॉपी किए गए JSON से श्रेणियाँ आयात करें';

  @override
  String get importIcsFile => 'ICS फ़ाइल आयात करें';

  @override
  String get importIcsFileDesc => '.ics कैलेंडर फ़ाइल से इवेंट पढ़ें';

  @override
  String get pasteIcs => 'ICS चिपकाएँ';

  @override
  String get pasteIcsDesc => 'कॉपी किए गए कैलेंडर टेक्स्ट से इवेंट आयात करें';

  @override
  String get copyJson => 'JSON कॉपी करें';

  @override
  String get copyJsonDesc =>
      'चुनी गई श्रेणियाँ JSON टेक्स्ट के रूप में कॉपी करें';

  @override
  String get shareIcs => 'ICS साझा करें';

  @override
  String get shareIcsDesc => 'चुने गए कैलेंडर .ics के रूप में साझा करें';

  @override
  String get saveIcs => 'ICS सहेजें';

  @override
  String get saveIcsDesc => 'चुने गए कैलेंडर .ics के रूप में सहेजें';

  @override
  String get copyIcs => 'ICS कॉपी करें';

  @override
  String get copyIcsDesc => 'चुने गए कैलेंडर ICS टेक्स्ट के रूप में कॉपी करें';

  @override
  String get importIcs => 'ICS आयात करें';

  @override
  String get icsContent => 'ICS सामग्री';

  @override
  String get pasteIcsContentHint => 'BEGIN:VCALENDAR सामग्री यहाँ चिपकाएँ';

  @override
  String importIcsPreviewPrompt(int count) {
    return '$count इवेंट मिले। उन्हें नई श्रेणी में जोड़ें या मौजूदा श्रेणी बदलें?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return '$count श्रेणियाँ आयात की गईं, $warningCount चेतावनियाँ';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'शुरू होने के समय के बिना एक इवेंट छोड़ दिया गया।';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'असमर्थित शुरू होने के समय वाला एक इवेंट छोड़ दिया गया।';

  @override
  String get importWarningAdjustedEnd =>
      'एक इवेंट का समाप्ति समय ठीक किया गया क्योंकि वह शुरू होने के समय के बाद नहीं था।';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'असमर्थित ICS फ़ील्ड नोट्स में जोड़े गए: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'असमर्थित दोहराव आवृत्ति अनदेखी की गई: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'ICS के रूप में कॉपी करने के लिए कैलेंडर चुनें';

  @override
  String get selectCalendarsToExportIcs =>
      'ICS के रूप में निर्यात करने के लिए कैलेंडर चुनें';

  @override
  String get exportIcsText => 'ICS टेक्स्ट निर्यात करें';

  @override
  String get exportJsonText => 'JSON टेक्स्ट निर्यात करें';

  @override
  String get dataRestoredFromBackupNotice =>
      'मुख्य फ़ाइल लोड नहीं हुई, इसलिए ऐप का डेटा पिछले बैकअप से पुनर्स्थापित किया गया।';

  @override
  String get dataBackupRestoreFailedNotice =>
      'मुख्य डेटा फ़ाइल और उसका बैकअप दोनों खराब हैं। ऐप अब नई प्रारंभिक स्थिति का उपयोग कर रहा है।';

  @override
  String get dataRecoveryCorruptTitle => 'आपके डेटा को पुनर्प्राप्त करना होगा';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked मुख्य डेटा फ़ाइल या उसका बैकअप नहीं पढ़ सका। लिखना रोकने से पहले सुरक्षित प्रतियाँ बनाई गईं।';

  @override
  String get dataRecoveryIoFailureTitle => 'स्टोरेज उपलब्ध नहीं है';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked अभी स्थानीय स्टोरेज तक नहीं पहुँच सकता। स्टोरेज की पहुँच या डिवाइस की उपलब्धता जाँचने के बाद फिर कोशिश करें। मौजूदा डेटा अधिलेखित नहीं होगा।';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'यह डेटा खोलने के लिए Sked अपडेट करें';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'यह डेटा Sked के नए संस्करण से बनाया गया है। दोबारा कोशिश करने से पहले ऐप अपडेट करें। डेटा की सुरक्षा के लिए नए सिरे से शुरू करना बंद है।';

  @override
  String get dataRecoveryRetryAction => 'फिर कोशिश करें';

  @override
  String get dataRecoveryArtifactsHint =>
      'पुनर्प्राप्ति फ़ाइलें या प्रभावित स्टोरेज स्थान नीचे दिए गए हैं। डेटा पुनर्प्राप्त होने तक फ़ाइलें न बदलें।';

  @override
  String get dataRecoveryArtifactsAction =>
      'पुनर्प्राप्ति फ़ाइलें और स्थान दिखाएँ';

  @override
  String get dataRecoveryStartFreshAction => 'नए डेटा से शुरू करें';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'नए डेटा से शुरू करें?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'सुरक्षित प्रतियाँ रखी जाएँगी, लेकिन Sked एक नई स्थानीय डेटा फ़ाइल बनाएगा। तभी जारी रखें जब आप पहले पुनर्प्राप्ति की कोशिश नहीं करना चाहते।';

  @override
  String get previousMonth => 'पिछला महीना';

  @override
  String get nextMonth => 'अगला महीना';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes मिनट';
  }

  @override
  String get reminderInProgress => 'चल रहा है';

  @override
  String get deleteCourseTitle => 'कोर्स हटाएँ';

  @override
  String get deleteCourseMessage => 'यह कोर्स हटाएँ?';

  @override
  String get showLunarCalendar => 'चंद्र कैलेंडर दिखाएँ';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count इवेंट';
  }

  @override
  String get defaultView => 'डिफ़ॉल्ट दृश्य';

  @override
  String get generalDefaultViewSection => 'शुरू करते समय';

  @override
  String get generalViewSwitchBehavior => 'दृश्य बदलने का बटन';

  @override
  String get settingsWorkspaceMode => 'सक्रिय कार्यस्थान';

  @override
  String get hideHomeWorkspaceNavigation => 'कार्यस्थान नेविगेशन छिपाएँ';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'कार्यस्थल नेविगेशन छिपाएँ। मुख्य स्क्रीन के कार्यस्थल मेन्यू से अब भी बदला जा सकता है।';

  @override
  String get generalDateLabelFormat => 'तारीख के लेबल का प्रारूप';

  @override
  String get generalDateLabelFormatLocalized => 'स्थानीयकृत (जुल॰ 2026)';

  @override
  String get generalDateLabelFormatSlash => 'स्लैश (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'टूलबार का लेआउट';

  @override
  String get toolbarNavigationSection => 'टूलबार नेविगेशन';

  @override
  String get toolbarNavigationHiddenBehavior => 'छिपे हुए आइटम';

  @override
  String get toolbarNavigationRemove => 'पूरी तरह छिपाएँ';

  @override
  String get toolbarNavigationMore => 'अधिक में ले जाएँ';

  @override
  String get toolbarNavigationReorder => 'टूलबार के आइटम का क्रम बदलें';

  @override
  String get toolbarNavigationVisibility => 'टूलबार का आइटम दिखाएँ';

  @override
  String get toolbarNavigationTimetable => 'टाइमटेबल चयनकर्ता';

  @override
  String get toolbarNavigationWeek => 'सप्ताह चयनकर्ता';

  @override
  String get toolbarNavigationView => 'दृश्य बदलने वाला';

  @override
  String get toolbarNavigationCategory => 'श्रेणी चयनकर्ता';

  @override
  String get toolbarNavigationDate => 'तारीख चयनकर्ता';

  @override
  String get generalToolbarWidthPolicy => 'टूलबार की जगह का आवंटन';

  @override
  String get generalToolbarWidthContent => 'स्वचालित आवंटन';

  @override
  String get generalToolbarWidthBalanced => 'संतुलित';

  @override
  String get generalToolbarWidthCalendarPriority => 'श्रेणी को प्राथमिकता';

  @override
  String get generalToolbarWidthDatePriority => 'तारीख को प्राथमिकता';

  @override
  String get generalViewSwitchCycle => 'दृश्यों को क्रम से बदलें';

  @override
  String get generalViewSwitchMenu => 'दृश्य मेनू खोलें';

  @override
  String get generalViewSwitchTooltip => 'दृश्य बदलें';

  @override
  String get generalViewSwitchMenuTooltip => 'दृश्य चुनें';

  @override
  String get generalViewLongPressTodayHint => 'आज पर जाने के लिए देर तक दबाएँ';

  @override
  String get generalScheduleDisplaySection => 'शेड्यूल का प्रदर्शन';

  @override
  String get generalTimeGridSection => 'समय ग्रिड';

  @override
  String get generalPopupSection => 'पॉपअप का व्यवहार';

  @override
  String get quickActionsSection => 'त्वरित कार्रवाइयाँ';

  @override
  String get showAddCourseFab => 'कोर्स जोड़ने का फ़्लोटिंग बटन दिखाएँ';

  @override
  String get showAddCourseFabHint =>
      'टाइमटेबल के निचले दाएँ कोने में कोर्स जोड़ने का फ़्लोटिंग बटन दिखाएँ या छिपाएँ।';

  @override
  String get showAddEventFab => 'इवेंट जोड़ने का फ़्लोटिंग बटन दिखाएँ';

  @override
  String get showAddEventFabHint =>
      'शेड्यूल के निचले दाएँ कोने में इवेंट जोड़ने का फ़्लोटिंग बटन दिखाएँ या छिपाएँ।';

  @override
  String get enableLongPressAddCourse =>
      'कोर्स जोड़ने के लिए खाली ग्रिड देर तक दबाएँ';

  @override
  String get enableLongPressAddCourseHint =>
      'कोर्स जोड़ने के लिए टाइमटेबल ग्रिड के खाली हिस्से को देर तक दबाएँ।';

  @override
  String get enableLongPressAddEvent =>
      'इवेंट जोड़ने के लिए खाली ग्रिड देर तक दबाएँ';

  @override
  String get enableLongPressAddEventHint =>
      'दिन या सप्ताह के दृश्य में इवेंट जोड़ने के लिए समय ग्रिड के खाली हिस्से को देर तक दबाएँ।';

  @override
  String get developerModeTitle => 'डेवलपर मोड';

  @override
  String get developerModeDescription =>
      'दृश्य और इंटरैक्शन जाँच के लिए संपूर्ण नमूना डेटा जोड़ने के टूल।';

  @override
  String get developerSampleLanguage => 'नमूना डेटा की भाषा';

  @override
  String get developerSampleChinese => 'चीनी';

  @override
  String get developerSampleEnglish => 'अंग्रेज़ी';

  @override
  String get developerSampleDataDescription =>
      'मौजूदा डेटा को बदले बिना एक समय-सारणी और श्रेणियों व इवेंट का समूह जोड़ता है।';

  @override
  String get developerAddSampleData => 'नमूना डेटा जोड़ें';

  @override
  String get developerSampleDataAdded =>
      'नमूना समय-सारणी और इवेंट डेटा जोड़ दिया गया।';

  @override
  String get developerModeLongPressHint =>
      'डेवलपर मोड खोलने के लिए 3 सेकंड तक दबाकर रखें';

  @override
  String get developerNotificationDiagnostics => 'सूचना निदान';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Android पर सूचनाओं की डिलीवरी की स्थिति जाँचें, मौजूदा रिमाइंडर योजना फिर बनाएँ और Sked की सामान्य सूचना सेवा से सुरक्षित परीक्षण सूचनाएँ भेजें।';

  @override
  String get developerNotificationUnsupported =>
      'सूचना निदान केवल Android पर उपलब्ध है।';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'सूचना निदान एजेंडा समन्वयक शुरू होने पर उपलब्ध होगा।';

  @override
  String get developerNotificationRefresh => 'निदान रीफ़्रेश करें';

  @override
  String get developerNotificationSystemStatus => 'सिस्टम में सूचना की अनुमति';

  @override
  String get developerNotificationPermissionAllowed => 'अनुमति है';

  @override
  String get developerNotificationPermissionBlocked => 'ब्लॉक किया गया';

  @override
  String get developerNotificationExactAlarm => 'सटीक अलार्म';

  @override
  String get developerNotificationExactAlarmAllowed => 'अनुमति है';

  @override
  String get developerNotificationExactAlarmBlocked => 'अनुमति नहीं है';

  @override
  String get developerNotificationPlan => 'शेड्यूल की सूचना योजना';

  @override
  String get developerNotificationCoverage => 'कवरेज';

  @override
  String get developerNotificationCoverageReady =>
      'सभी ज्ञात सीमित रिमाइंडर सीधे तय कर दिए गए हैं';

  @override
  String get developerNotificationCoverageRenewable =>
      'दोहराए जाने वाले रिमाइंडर लंबे समय की कवरेज के लिए यथासंभव फिर तय किए जाते हैं';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'सीधे तय किए जाने वाले अलार्म की क्षमता भर गई है; बाद के रिमाइंडर यथासंभव फिर तय किए जाएँगे';

  @override
  String get developerNotificationCoverageBlocked =>
      'सटीक डिलीवरी की शर्तें पूरी नहीं हुईं';

  @override
  String get developerNotificationCoverageFailed =>
      'पिछला रिमाइंडर सिंक विफल हुआ';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled सीधे तय अलार्म / क्षमता $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled तय, $planned योजनाबद्ध';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'पिछली त्रुटि: $message';
  }

  @override
  String get developerNotificationRunMaintenance => 'सूचना योजना फिर बनाएँ';

  @override
  String get developerNotificationMaintenanceComplete =>
      'सूचना योजना फिर बनाई गई।';

  @override
  String get developerNotificationTestChannel => 'परीक्षण चैनल';

  @override
  String get developerNotificationTestCourse => 'कोर्स रिमाइंडर';

  @override
  String get developerNotificationTestSchedule => 'शेड्यूल रिमाइंडर';

  @override
  String get developerNotificationImmediateTest => 'अभी परीक्षण सूचना भेजें';

  @override
  String get developerNotificationThirtySecondTest =>
      '30 सेकंड बाद पृष्ठभूमि परीक्षण तय करें';

  @override
  String get developerNotificationImmediateQueued =>
      'तुरंत परीक्षण सूचना भेजी गई।';

  @override
  String get developerNotificationThirtySecondQueued =>
      'पृष्ठभूमि परीक्षण 30 सेकंड बाद के लिए तय किया गया।';

  @override
  String get developerNotificationAppSwitch => 'ऐप का रिमाइंडर स्विच';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'सामान्य रिमाइंडर चालू हैं';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'सामान्य रिमाइंडर बंद हैं; डेवलपर परीक्षण फिर भी चल सकते हैं';

  @override
  String get developerNotificationTimeZone => 'स्थानीय समय क्षेत्र';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'अभी बनाया नहीं गया। डेवलपर परीक्षण इसे बना देगा।';

  @override
  String get developerNotificationChannelEnabledState => 'चालू';

  @override
  String get developerNotificationChannelBlockedState => 'ब्लॉक किया गया';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'महत्त्व: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'महत्त्व उपलब्ध नहीं है';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending लंबित / $active सक्रिय';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'सिस्टम द्वारा पिछली बार दिखाया गया: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'अभी कोई पुनर्गणना दर्ज नहीं हुई।';

  @override
  String get developerNotificationNextReminder => 'अगला वास्तविक रिमाइंडर';

  @override
  String get developerNotificationNoPendingReminder =>
      'मौजूदा योजना में कोई आगामी रिमाइंडर नहीं है';

  @override
  String get developerNotificationNextMaintenance => 'अगला रखरखाव';

  @override
  String get developerNotificationNextRenewal => 'अगला यथासंभव पुनर्निर्धारण';

  @override
  String get developerNotificationNoMaintenance => 'तय नहीं किया गया';

  @override
  String get developerNotificationTruncation => 'योजना में कटौती';

  @override
  String developerNotificationTruncationCount(int count) {
    return 'योजना की सीमा के कारण $count छोड़े गए';
  }

  @override
  String get developerNotificationLastReconciliation => 'पिछली पुनर्गणना';

  @override
  String get developerNotificationLastSynchronization => 'पिछला रिमाइंडर सिंक';

  @override
  String get developerNotificationLateRecovery =>
      'देर से रिमाइंडर की पुनर्प्राप्ति';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count रिमाइंडर उनके मूल समय के बाद बहाल कर भेजे गए';
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
  String get developerNotificationReconcileOriginForeground => 'अग्रभूमि';

  @override
  String get developerNotificationReconcileOriginBackground => 'पृष्ठभूमि';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'पूर्ण पुनर्गणना';

  @override
  String get developerNotificationReconcileModeMaintenance => 'रखरखाव';

  @override
  String get developerNotificationReconcileModeRecovery => 'पुनर्प्राप्ति';

  @override
  String get developerNotificationRunRecovery => 'रिमाइंडर पुनर्प्राप्त करें';

  @override
  String get developerNotificationRecoveryComplete =>
      'रिमाइंडर की पुनर्प्राप्ति पूरी हुई';

  @override
  String get developerNotificationReconcileResultSuccess => 'सफल';

  @override
  String get developerNotificationReconcileResultSkipped => 'छोड़ा गया';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'सटीक डिलीवरी की सभी शर्तें पूरी होने तक ब्लॉक है';

  @override
  String get developerNotificationReconcileResultFailed => 'विफल';

  @override
  String get developerNotificationBackgroundLimits =>
      'निर्माता के पृष्ठभूमि प्रतिबंध';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'निर्माता के पृष्ठभूमि प्रतिबंध डिलीवरी को प्रभावित कर सकते हैं।';

  @override
  String get developerNotificationAutostart => 'निर्माता का पृष्ठभूमि प्रारंभ';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'निर्माता $vendor; निर्माता की सेटिंग्स का विकल्प उपलब्ध है। Android इसकी अनुमति की स्थिति नहीं बता सकता।';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'निर्माता $vendor; विकल्प के रूप में ऐप का विवरण खोला जाएगा। Android इसकी अनुमति की स्थिति नहीं बता सकता।';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'निर्माता की पृष्ठभूमि सेटिंग्स का कोई विकल्प उपलब्ध नहीं है।';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'पिछली बार खोला गया स्थान: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'निर्माता की सेटिंग्स';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'ऐप का विवरण';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'कोई नहीं';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'पुनरारंभ के बाद पुनर्प्राप्ति की सीमाएँ';

  @override
  String get developerNotificationRebootBoundary =>
      'पहली बार अनलॉक करने के बाद पुनर्प्राप्ति शुरू होती है; ज़बरन रोका गया ऐप अपने आप शुरू नहीं हो सकता।';

  @override
  String get developerNotificationTestChecking =>
      'सूचना की स्थिति जाँचे जाने के दौरान परीक्षण उपलब्ध नहीं हैं।';

  @override
  String get developerNotificationTestBlockedSystem =>
      'सिस्टम सूचनाएँ ब्लॉक हैं, इसलिए परीक्षण उपलब्ध नहीं हैं।';

  @override
  String get developerNotificationTestBlockedChannel =>
      'चुना गया सूचना चैनल ब्लॉक है, इसलिए परीक्षण उपलब्ध नहीं हैं।';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Windows की सूचना सेटिंग्स से प्रबंधित';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Windows पर लागू नहीं';

  @override
  String get developerNotificationWindowsIdentity => 'Windows पैकेज की पहचान';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX पहचान उपलब्ध है; सक्रिय सूचना कार्ड हटाए जा सकते हैं';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'सक्रिय सूचना कार्ड भरोसेमंद ढंग से हटाने के लिए MSIX संस्करण इंस्टॉल करें';

  @override
  String get collapseWorkspaceNavigation =>
      'कार्यस्थान नेविगेशन संक्षिप्त करें';

  @override
  String get expandWorkspaceNavigation => 'कार्यस्थान नेविगेशन विस्तृत करें';

  @override
  String get schoolWebImportExitBrowser => 'इन-ऐप ब्राउज़र से बाहर निकलें';

  @override
  String get schoolWebImportEditAddress => 'पता संपादित करें';

  @override
  String get schoolWebImportAddressLabel => 'वेब पता';

  @override
  String get schoolWebImportOpenAddress => 'खोलें';

  @override
  String get schoolWebImportAddressInvalid =>
      'होस्ट के साथ कोई HTTP या HTTPS पता दर्ज करें।';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'इस वेबपेज ने एक नई विंडो मांगी है जिसे इस डिवाइस पर नहीं खोला जा सकता।';

  @override
  String get schoolWebImportSecureConnection => 'सुरक्षित कनेक्शन';

  @override
  String get schoolWebImportInsecureConnection => 'असुरक्षित कनेक्शन';

  @override
  String get schoolWebImportSignInConsentTitle => 'स्कूल साइन-इन खोलें?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'स्कूल साइन-इन, फ़ॉर्म या सर्वर रीडायरेक्ट के माध्यम से स्कूल और उसके साइन-इन प्रदाताओं को क्रेडेंशियल भेज सकता है। Android हर ऐसे ट्रांसफ़र को अलग गंतव्य पुष्टि के लिए रोक नहीं सकता। केवल तभी जारी रखें जब आप इस आयात सत्र के लिए उन पर भरोसा करते हों:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'असुरक्षित स्कूल साइन-इन खोलें?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'यह स्कूल साइन-इन HTTP का उपयोग करता है। इस कनेक्शन को देख या बदल सकने वाला कोई भी व्यक्ति आपके क्रेडेंशियल और पेज की सामग्री पढ़ या बदल सकता है। केवल तभी जारी रखें जब आप इसके लिए यह जोखिम स्वीकार करते हों:\n\n$origin';
  }

  @override
  String get notificationSettingsSection => 'रिमाइंडर और सूचनाएँ';

  @override
  String get notificationCoverage => 'रिमाइंडर कवरेज';

  @override
  String get notificationCoverageRenewable =>
      'बिना समाप्ति तारीख वाले दोहराए जाने वाले शेड्यूल लंबे समय की कवरेज के लिए पृष्ठभूमि में फिर तय किए जाते हैं।';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android सीधे अधिकतम $capacity रिमाइंडर तय कर सकता है; बाद के रिमाइंडर पहले से फिर तय करने की कोशिश की जाती है।';
  }

  @override
  String get notificationSettingsEnabled => 'रिमाइंडर और सूचनाएँ चालू करें';

  @override
  String get notificationSettingsEnabledHint =>
      'सूचनाएँ केवल उन आइटम के लिए तय होती हैं जिनमें रिमाइंडर है। डिफ़ॉल्ट अपनाने वाले कोर्स के लिए नीचे कोर्स का डिफ़ॉल्ट रिमाइंडर तय करें।';

  @override
  String get notificationPrecisionLimitations =>
      'रिमाइंडर सिस्टम अनुमतियों और बैकग्राउंड संचालन पर निर्भर हैं। डिवाइस बंद होने, समय बदलने या सिस्टम प्रतिबंधों से देरी हो सकती है।';

  @override
  String get notificationSettingsEnabledSummary => 'चालू';

  @override
  String get notificationSettingsDisabledSummary => 'बंद';

  @override
  String get notificationDefaultsSection => 'डिफ़ॉल्ट रिमाइंडर';

  @override
  String get notificationCourseDefaultReminder => 'कोर्स का डिफ़ॉल्ट रिमाइंडर';

  @override
  String get notificationGeneralDefaultReminder =>
      'शेड्यूल का डिफ़ॉल्ट रिमाइंडर';

  @override
  String get notificationReminderOff => 'कोई रिमाइंडर नहीं';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes मिनट पहले';
  }

  @override
  String get notificationPermission => 'सूचना की अनुमति';

  @override
  String get notificationPermissionGranted => 'सिस्टम ने अनुमति दी है';

  @override
  String get notificationPermissionDenied => 'सिस्टम ने ब्लॉक किया है';

  @override
  String get notificationPermissionChecking => 'अनुमति जाँची जा रही है…';

  @override
  String get notificationPermissionRequest => 'अनुमति माँगें';

  @override
  String get notificationPermissionOpenSettings => 'सिस्टम सेटिंग्स खोलें';

  @override
  String get notificationPermissionRequestFailed =>
      'सूचना की अनुमति नहीं पढ़ी जा सकी। फिर कोशिश करें।';

  @override
  String get notificationExactAlarm => 'सटीक अलार्म की अनुमति';

  @override
  String get notificationExactAlarmAllowed => 'सिस्टम ने अनुमति दी है';

  @override
  String get notificationExactAlarmRequired =>
      'सटीक समय पर रिमाइंडर के लिए आवश्यक';

  @override
  String get notificationExactAlarmRequest => 'सटीक अलार्म की अनुमति दें';

  @override
  String get notificationBatteryOptimization => 'बैटरी ऑप्टिमाइज़ेशन';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Android के बैटरी ऑप्टिमाइज़ेशन से छूट मिली है';

  @override
  String get notificationBatteryOptimizationRequired =>
      'सटीक रिमाइंडर के लिए Android के बैटरी ऑप्टिमाइज़ेशन से छूट आवश्यक है';

  @override
  String get notificationBatteryOptimizationRequest =>
      'बैटरी ऑप्टिमाइज़ेशन सेटिंग्स खोलें';

  @override
  String get notificationAutostart => 'निर्माता का पृष्ठभूमि प्रारंभ';

  @override
  String get notificationAutostartVendorHint =>
      'अपने आप शुरू होने या पृष्ठभूमि में चलने की अनुमति दें ताकि पुनरारंभ के बाद रिमाइंडर बहाल हो सकें।';

  @override
  String get notificationAutostartFallbackHint =>
      'Sked के ऐप विवरण खोलें और पृष्ठभूमि में चलने की अनुमति दें। Android निर्माता की इस सेटिंग को जाँच नहीं सकता।';

  @override
  String get notificationAutostartUnavailable =>
      'निर्माता की सेटिंग्स का पृष्ठ नहीं मिला। Sked के ऐप विवरण स्वयं जाँचें।';

  @override
  String get notificationAutostartRequest =>
      'निर्माता की पृष्ठभूमि सेटिंग्स खोलें';

  @override
  String get notificationAutostartOpenFailed =>
      'निर्माता की पृष्ठभूमि सेटिंग्स नहीं खुल सकीं। Sked के ऐप विवरण स्वयं जाँचें।';

  @override
  String get notificationLockScreenTitles => 'लॉक स्क्रीन पर शीर्षक दिखाएँ';

  @override
  String get notificationLockScreenTitlesHint =>
      'बंद होने पर सूचना का विवरण लॉक स्क्रीन पर निजी रहता है।';

  @override
  String get notificationWidgets => 'होम स्क्रीन विजेट';

  @override
  String get notificationWidgetsDesc =>
      'Sked विजेट रीफ़्रेश करें और लॉन्चर से जोड़ने का तरीका जानें।';

  @override
  String get notificationWidgetsDialogTitle => 'Sked विजेट जोड़ें';

  @override
  String get notificationWidgetsDialogMessage =>
      'डिवाइस के होम स्क्रीन पर खाली जगह को देर तक दबाएँ, विजेट चुनें और Sked विजेट जोड़ें। विजेट आपके अगले कोर्स या इवेंट दिखाता है।';

  @override
  String get notificationWidgetsRefresh => 'विजेट रीफ़्रेश करें';

  @override
  String get notificationWidgetsRefreshed => 'विजेट रीफ़्रेश किए गए';

  @override
  String get notificationPlatformUnsupported =>
      'यह प्लेटफ़ॉर्म मूल सूचनाएँ उपलब्ध नहीं कराता।';

  @override
  String get workspaceFeatures => 'सुविधा प्रबंधन';

  @override
  String get workspaceBoth => 'कक्षा समय-सारणी और कार्यक्रम';

  @override
  String get workspaceOnlyStudent => 'केवल कक्षा समय-सारणी';

  @override
  String get workspaceOnlyGeneral => 'केवल कार्यक्रम';

  @override
  String get workspaceDisableTitle => 'यह कार्यक्षेत्र बंद करें?';

  @override
  String get workspaceDisableMessage =>
      'डेटा और प्राथमिकताएँ बनी रहेंगी। यहाँ दोबारा चालू करने तक इसकी सुविधाएँ और रिमाइंडर बंद रहेंगे।';

  @override
  String get workspaceEnableHint =>
      'अपनी ज़रूरत की सुविधाएँ चुनें। कम से कम एक चालू रहनी चाहिए।';

  @override
  String get workspaceLastRequired =>
      'कम से कम एक कार्यक्षेत्र चालू रहना चाहिए।';

  @override
  String get workspaceReminderCleanupFailed =>
      'कार्यक्षेत्र बंद है, लेकिन रिमाइंडर हटाए नहीं जा सके। सूचनाएँ पुनर्स्थापित करने का फिर प्रयास करें।';

  @override
  String get settingsSearch => 'सेटिंग खोजें';

  @override
  String get settingsNoResults => 'कोई मेल खाती सेटिंग नहीं';

  @override
  String get settingsDataPrivacy => 'डेटा और गोपनीयता';

  @override
  String get workspacePreferences => 'प्रदर्शन और नियंत्रण';

  @override
  String get workspaceManage => 'प्रबंधित करें';

  @override
  String get selectedDayAgenda => 'चुना गया दिन';

  @override
  String get notificationTroubleshooting => 'अनुमतियाँ और समस्या निवारण';

  @override
  String get settingsConnection => 'कनेक्शन';

  @override
  String get settingsAdvanced => 'उन्नत';

  @override
  String get unsavedChangesMessage =>
      'आपके बदलाव सहेजे नहीं गए हैं। उन्हें छोड़कर बाहर जाएँ?';

  @override
  String get backupWorkspaceSelection =>
      'पूरे बैकअप में डेटा और चालू कार्यक्षेत्रों का चयन शामिल होता है।';

  @override
  String get assistantLayoutPreview => 'AI · लेआउट पूर्वावलोकन';

  @override
  String get assistantSelectionContext =>
      'मौजूदा चयन को संदर्भ के रूप में उपयोग करता है';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'संदेश का मसौदा';

  @override
  String get assistantPreviewNoSend =>
      'केवल लेआउट का पूर्वावलोकन है। कुछ भी भेजा या बदला नहीं जाएगा।';

  @override
  String get resizePanel => 'पैनल का आकार बदलें';

  @override
  String get minimizeWindow => 'छोटा करें';

  @override
  String get maximizeWindow => 'बड़ा करें';

  @override
  String get restoreWindow => 'विंडो का आकार बहाल करें';

  @override
  String get closeWindow => 'विंडो बंद करें';

  @override
  String get courseSystemReminder => 'सिस्टम रिमाइंडर';

  @override
  String courseReminderInherit(String reminder) {
    return 'डिफ़ॉल्ट उपयोग करें ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'सूचना सेटिंग्स में सिस्टम रिमाइंडर बंद हैं। इस कोर्स की पसंद फिर भी सहेजी जा सकती है।';

  @override
  String get courseReminderDefaultOff =>
      'कोर्स का कोई डिफ़ॉल्ट रिमाइंडर तय नहीं है। यहाँ कस्टम रिमाइंडर चुनें या सूचना सेटिंग्स में डिफ़ॉल्ट तय करें।';

  @override
  String get courseReminderDeliveryHint =>
      'यह पसंद कोर्स के साथ सहेजी जाती है। डिलीवरी सिस्टम की सूचना अनुमतियों और पृष्ठभूमि प्रतिबंधों पर निर्भर करती है।';

  @override
  String get courseReminderPermissionUnknown =>
      'सिस्टम की सूचना स्थिति अभी नहीं जाँची गई है। रिमाइंडर पर निर्भर होने से पहले सूचना सेटिंग्स की समीक्षा करें।';

  @override
  String get courseReminderMinutesLabel => 'कक्षा से कितने मिनट पहले';

  @override
  String get exportAction => 'निर्यात करें';

  @override
  String get datePickerSelectWeek => 'सप्ताह चुनें';

  @override
  String get datePickerSelectMonth => 'महीना चुनें';

  @override
  String get generalDateLabelFormatDescription =>
      'डेस्कटॉप और छोटी स्क्रीन पर तारीख नेविगेशन पर लागू होता है।';

  @override
  String get dateRangeTitle => 'तारीख सीमा चुनें';

  @override
  String get dateRangeCustom => 'कस्टम';

  @override
  String get dateRangeChooseStart => 'शुरुआत की तारीख चुनें';

  @override
  String get dateRangeChooseEnd => 'समाप्ति की तारीख चुनें';

  @override
  String get dateRangeLimit => 'शुरुआत और समाप्ति सहित 1–14 दिन चुनें।';

  @override
  String dateRangeCustomDays(int days) {
    return 'कस्टम · $days दिन';
  }

  @override
  String get timePickerWheelMode => 'स्क्रॉल व्हील से चुनें';

  @override
  String get courseReminderUseDefault => 'डिफ़ॉल्ट उपयोग करें';

  @override
  String get courseReminderInvalidMinutes =>
      'मिनटों की पूर्ण संख्या दर्ज करें, शून्य या उससे अधिक।';

  @override
  String get generalCustomColumnWidth => 'कस्टम दृश्य में कॉलम की चौड़ाई';

  @override
  String get generalCustomColumnWidthAuto => 'स्वचालित';

  @override
  String get generalCustomColumnWidthManual => 'न्यूनतम चौड़ाई';

  @override
  String get generalCustomColumnWidthMinimum => 'हर दिन की न्यूनतम चौड़ाई';

  @override
  String get generalCustomColumnWidthHint =>
      'सभी तारीखों की यही न्यूनतम चौड़ाई होगी। कॉलम उपलब्ध जगह भरते हैं या क्षैतिज स्क्रॉल होते हैं। केवल कस्टम दृश्य पर लागू होता है।';

  @override
  String get settingsAppearanceLanguage => 'दिखावट और भाषा';

  @override
  String get settingsAppearanceDetails => 'रंग और रूपरेखाएँ';

  @override
  String get monthNoEvents => 'इस दिन कोई इवेंट नहीं है';

  @override
  String get settingsOverview => 'अवलोकन';

  @override
  String get settingsThemeTarget => 'इसके लिए थीम';

  @override
  String get settingsColorMode => 'रंग मोड';

  @override
  String get settingsNotificationPreferences => 'रिमाइंडर की पसंद';

  @override
  String get settingsNotificationPreferencesSummary =>
      'डिफ़ॉल्ट रिमाइंडर, अनुमतियाँ और भरोसेमंद संचालन';

  @override
  String get settingsFeaturesSummary => 'कार्यस्थान और नेविगेशन';

  @override
  String get settingsPrivacySummary => 'गोपनीयता नीति और स्थानीय डेटा मिटाना';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पीरियड',
      one: '1 पीरियड',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'पीरियड';

  @override
  String get periodTimesDurationColumn => 'अवधि';

  @override
  String get periodTimesGapColumn => 'विराम';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes मिनट';
  }

  @override
  String get periodTimesSavePending => 'सहेजने की प्रतीक्षा में…';

  @override
  String get periodTimesSaveFailed => 'सहेजा नहीं गया · सहेजना विफल हुआ';

  @override
  String get periodTimesInvalidStatus =>
      'सहेजा नहीं गया · चिह्नित समय ठीक करें';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked यह पुष्टि नहीं कर सका कि पिछली सेव प्रक्रिया के बदलाव वापस किए गए हैं या नहीं। लिखना रोक दिया गया है और पुनर्प्राप्ति प्रतियाँ सुरक्षित हैं। स्टोरेज जाँचें और डेटा फिर से लोड करें।';

  @override
  String get settingsPanelDisplayMode => 'पैनल दिखाने का तरीका';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'समय-सारणी और कैलेंडर के लिए साझा';

  @override
  String get settingsPanelDisplayOverlay => 'ऊपर दिखाएँ';

  @override
  String get settingsPanelDisplaySideBySide => 'साथ-साथ';

  @override
  String get settingsPanelDisplayAutomatic => 'स्वचालित';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'कैलेंडर की चौड़ाई बदले बिना दाईं ओर ऊपर दिखाता है।';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'साथ-साथ दिखाने को प्राथमिकता देता है; कैलेंडर बहुत संकरा होने पर ही ऊपर दिखाता है।';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'कैलेंडर पढ़ने योग्य चौड़ाई में हो तो साथ-साथ, अन्यथा ऊपर दिखाता है।';

  @override
  String get toolbarNavigationEssentialHint =>
      'टूलबार में सेटिंग्स या कार्यस्थान बंद करने पर वह हटने के बजाय अधिक में चला जाता है। ज़रूरी कार्रवाइयाँ होने तक अधिक छिपाया नहीं जा सकता। कार्यस्थान बदलने का विकल्प तभी दिखता है जब नीचे का नेविगेशन छिपा हो और कई कार्यस्थान चालू हों।';

  @override
  String get reminderEnded => 'समाप्त';

  @override
  String get reminderAutoCloseHint =>
      '10 सेकंड बाद बंद होगा। खुला रखने के लिए पैनल का उपयोग करें।';

  @override
  String get showReminderIndependently => 'अलग से खोलें';

  @override
  String get categoryManagerTitle => 'श्रेणियाँ प्रबंधित करें';

  @override
  String get categoryHidden => 'छिपा हुआ';

  @override
  String get categoryShowOnCalendar => 'कैलेंडर में दिखाएँ';

  @override
  String get categoryHideOnCalendar => 'कैलेंडर से छिपाएँ';

  @override
  String get categoryEditColor => 'श्रेणी का रंग बदलें';

  @override
  String get categoryThemePalette => 'थीम के रंग';

  @override
  String get categoryCustomColor => 'कस्टम';

  @override
  String get colorHexInvalid => 'छह अंकों का हेक्स रंग कोड दर्ज करें।';

  @override
  String categoryColorSlot(int number) {
    return 'थीम का रंग $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'स्टोर के अपडेट बाद में आ सकते हैं। उपलब्धता के लिए स्टोर पृष्ठ देखें।';

  @override
  String get storePrereleaseNotice =>
      'पूर्व-रिलीज़ अपडेट की सूचनाएँ पाने से आप स्टोर के परीक्षण कार्यक्रम में शामिल नहीं होते।';

  @override
  String get updateFoundTitle => 'नया संस्करण उपलब्ध है';

  @override
  String get updateNoNotes => 'कोई रिलीज़ नोट्स नहीं दिए गए हैं।';

  @override
  String get updateLater => 'बाद में';

  @override
  String get updateRetry => 'फिर कोशिश करें';

  @override
  String get updatePrerelease => 'पूर्व-रिलीज़';

  @override
  String get updateNetworkFailure =>
      'अपडेट की जाँच नहीं हो सकी। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String updateNoNewerVersion(String version) {
    return 'कोई नया संस्करण नहीं मिला (मौजूदा: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'बैकअप बहाल किया जा रहा है…';

  @override
  String get backupRestoreInProgressMessage =>
      'बहाली पूरी होने के बाद डेटा और सेटिंग बदली जा सकती हैं। आप उन्हें अभी भी देख सकते हैं।';
}
