// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'เพื่อนร่วมเรียน';

  @override
  String weekLabel(int week) {
    return 'สัปดาห์ $week';
  }

  @override
  String get addCourse => 'เพิ่มหลักสูตร';

  @override
  String get settings => 'การตั้งค่า';

  @override
  String get multiTimetableSwitch => 'เปลี่ยนตารางเวลา';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'ตารางเวลาปัจจุบัน · $weeks สัปดาห์';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'แตะเพื่อสวิตช์ · $weeks สัปดาห์';
  }

  @override
  String get editTimetable => 'แก้ไขตารางเวลา';

  @override
  String get createTimetable => 'ตารางเวลาใหม่';

  @override
  String get jumpToWeek => 'กระโดดไปสัปดาห์';

  @override
  String get timetable => 'ตารางเวลา';

  @override
  String get timetableName => 'ชื่อตารางเวลา';

  @override
  String get totalWeeks => 'สัปดาห์ทั้งหมด';

  @override
  String get delete => 'ลบ';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get save => 'บันทึก';

  @override
  String get deleteTimetableTitle => 'ลบตารางเวลา';

  @override
  String deleteTimetableMessage(Object name) {
    return 'ลบ \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'ยังไม่มีตารางเวลา';

  @override
  String get noTimetableMessage => 'สร้างตารางเวลาหรือนําเข้าจากไฟล์ JSON';

  @override
  String get importTimetable => 'ตารางเวลานําเข้า';

  @override
  String get courseName => 'ชื่อหลักสูตร';

  @override
  String get location => 'สถานที่ตั้ง';

  @override
  String get dayOfWeek => 'วัน';

  @override
  String get semesterWeeks => 'สัปดาห์';

  @override
  String get startTime => 'เวลาเริ่มต้น';

  @override
  String get endTime => 'เวลาสิ้นสุด';

  @override
  String get linkedPeriods => 'ระยะเวลาที่เชื่อมโยง';

  @override
  String get linkedPeriodsUnmatched =>
      'ไม่มีระยะเวลาที่ตรงกับสําหรับเวลาปัจจุบัน แตะเพื่อเลือกด้วยมือ';

  @override
  String periodRangeLabel(int start, int end) {
    return 'ระยะเวลา $start-$end';
  }

  @override
  String get teacherName => 'อาจารย์';

  @override
  String get credits => 'เครดิต';

  @override
  String get remarks => 'ข้อความ';

  @override
  String get customFields => 'ฟิลด์ที่กำหนดเอง';

  @override
  String get customFieldsHint => 'หนึ่งต่อเส้นรูปแบบ: คีย์: ค่า';

  @override
  String get selectDayOfWeek => 'เลือกวัน';

  @override
  String get selectSemesterWeeks => 'เลือกสัปดาห์';

  @override
  String get selectAll => 'เลือกทั้งหมด';

  @override
  String get clear => 'ล้าง';

  @override
  String get confirm => 'ยืนยัน';

  @override
  String get selectLinkedPeriods => 'เลือกระยะเวลาที่เชื่อมโยง';

  @override
  String get addCourseTitle => 'เพิ่มหลักสูตร';

  @override
  String get editCourseTitle => 'แก้ไขหลักสูตร';

  @override
  String get editCourseTooltip => 'แก้ไขหลักสูตร';

  @override
  String get place => 'สถานที่ตั้ง';

  @override
  String get time => 'เวลา';

  @override
  String get notFilled => 'ไม่เติม';

  @override
  String get none => 'ไม่มี';

  @override
  String get conflictCourses => 'หลักสูตรที่ขัดแย้ง';

  @override
  String get locationNotFilled => 'สถานที่ไม่เติม';

  @override
  String get setAsDisplayed => 'ตั้งตามที่แสดง';

  @override
  String get editThisCourse => 'แก้ไขหลักสูตรนี้';

  @override
  String get settingsTitle => 'การตั้งค่า';

  @override
  String get settingsSectionTimetable => 'Timetable';

  @override
  String get settingsSectionGeneralSchedule => 'General schedule';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionCurrentWorkspace => 'Current timetable / calendar';

  @override
  String get settingsSectionAppearanceLanguage => 'Appearance & language';

  @override
  String get settingsSectionDataSecurity => 'Data & security';

  @override
  String get settingsSectionAbout => 'About Sked';

  @override
  String get noTimetableSettings => 'ปัจจุบันไม่มีตารางเวลาสำหรับการตั้งค่า';

  @override
  String get semesterStartDate => 'วันเริ่มต้นภาคศึกษา';

  @override
  String get periodTimeSets => 'ระยะเวลาที่กำหนดไว้';

  @override
  String get noPeriodTimeAvailable => 'ไม่มีเวลาที่กำหนดไว้';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count ระยะเวลา';
  }

  @override
  String get coursePopupDismissSetting =>
      'อนุญาตให้แตะด้านนอกเพื่อปิดป๊อปอัปหลักสูตร';

  @override
  String get coursePopupDismissSettingHint =>
      'การปิดนี้ยังปิดการเลื่อนการไล่ลง';

  @override
  String get preserveTimetableGaps => 'รักษาช่องว่างของตารางเวลา';

  @override
  String get preserveTimetableGapsHint =>
      'เมื่อหยุด ช่องว่างอาหารกลางวันและช่องว่างจะล้มลง ดังนั้นเรียนในภายหลังจะย้ายขึ้น';

  @override
  String get showPastEndedCourses => 'แสดงหลักสูตรที่สิ้นสุดในอดีต';

  @override
  String get showPastEndedCoursesHint =>
      'แสดงหลักสูตรที่เสร็จสิ้นแล้วในสัปดาห์ปัจจุบันจริงด้วยสไตล์สีเทาอ่อน';

  @override
  String get showFutureCourses => 'แสดงหลักสูตรในอนาคต';

  @override
  String get showFutureCoursesHint =>
      'แสดงหลักสูตรที่ไม่ได้ใช้งานในสัปดาห์นี้ แต่จะปรากฏในสัปดาห์ต่อมา ด้วยรูปแบบสีเทา';

  @override
  String get timetableDisplaySettings => 'การแสดงตารางและการปฏิสัมพันธ์';

  @override
  String get timetableDisplaySettingsDesc =>
      'การยกเลิกป๊อปอัป, ช่องว่าง, หลักสูตรสีเทา, และบรรทัดตาราง';

  @override
  String get showTimetableGridLines => 'แสดงเส้นทางตารางเวลา';

  @override
  String get showTimetableGridLinesHint =>
      'ควบคุมว่าเส้นทางตารางแนวนอนและแนวตั้งเห็นได้หรือไม่ในตารางเวลา';

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
  String get liveCourseOutlineColor => 'สีโครงสร้างหลักสูตร';

  @override
  String get liveCourseOutlineColorHint =>
      'เลือกว่าโครงสร้างเป้าหมายหลักสูตรปัจจุบัน/ต่อไป หรือหลักสูตรทั้งหมดที่แสดงบนหน้าปัจจุบัน';

  @override
  String get liveCourseOutlineSettings => 'รายละเอียดหลักสูตร';

  @override
  String get liveCourseOutlineSettingsHint =>
      'กำหนดค่าถูกเปิดใช้รูปร่างหรือไม่, มันเป้าหมายอะไร, มันติดตามสีหัวข้อ, และสีรูปร่างที่มีประสิทธิภาพหรือไม่.';

  @override
  String get liveCourseOutlineEnabled => 'เปิดใช้งานรูปร่าง';

  @override
  String get liveCourseOutlineFollowTheme => 'ตามสีธีม';

  @override
  String get liveCourseOutlineTarget => 'เป้าหมายร่าง';

  @override
  String get liveCourseOutlineTargetCurrentOrNext =>
      'หลักสูตรปัจจุบัน/หลักสูตรต่อไป';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'หลักสูตรที่แสดงทั้งหมด';

  @override
  String get liveCourseOutlineEffectiveColor => 'สีที่มีประสิทธิภาพ';

  @override
  String get liveCourseOutlineCustomColor => 'สีร่างกายที่กำหนดเอง';

  @override
  String get liveCourseOutlineWidth => 'ความกว้างของรูปร่าง';

  @override
  String get outlineWidthUnit => 'พิกซ์';

  @override
  String get language => 'ภาษา';

  @override
  String get languagePageDescription => 'เลือกหนึ่งในภาษาที่มีอยู่ในแอพจริง ๆ';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'ภาษาไทย';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'การตอบสนอง API';

  @override
  String get theme => 'ธีม';

  @override
  String get themeFollowSystem => 'ติดตามระบบ';

  @override
  String get themeLight => 'แสง';

  @override
  String get themeDark => 'มืด';

  @override
  String get themeColor => 'สีธีม';

  @override
  String get themeColorModeSingle => 'สีธีมเดียว';

  @override
  String get themeColorModeColorful => 'สีสัน';

  @override
  String get themeColorUiColors => 'สี UI';

  @override
  String get themeColorCourseColors => 'สีหลักสูตร';

  @override
  String get themeColorPrimary => 'หลักสูตร';

  @override
  String get themeColorSecondary => 'มัธยม';

  @override
  String get themeColorTertiary => 'ระดับสูง';

  @override
  String get themeColorCourseText => 'ข้อความหลักสูตร';

  @override
  String get themeColorCourseTextAuto => 'อัตโนมัติ';

  @override
  String get themeColorCourseTextCustom => 'สีที่กำหนดเอง';

  @override
  String get themeColorCourseColorsEmpty =>
      'สีหลักสูตรจะถูกสร้างขึ้นหลังจากนำเข้าตลาดเวลา';

  @override
  String get themeCustomColor => 'สีที่กำหนดเอง';

  @override
  String get themeApplyCustomColor => 'ใช้สี';

  @override
  String get themeApplySettings => 'ใช้การตั้งค่า';

  @override
  String get dataImportExport => 'ข้อมูลนำเข้าและส่งออก';

  @override
  String get dataImportExportDesc =>
      'นำเข้าข้อมูลเต็มหรือตารางเวลาเดียว หรือส่งออกตารางเวลาปัจจุบัน/ทั้งหมด';

  @override
  String get appBackupTitle => 'สำรองและกู้คืนแอป';

  @override
  String get appBackupSubtitle =>
      'สำรองหรือกู้คืนตารางเรียน ตารางเวลา การตั้งค่า และเว็บไซต์โรงเรียน ไม่รวมคีย์ API';

  @override
  String get appBackupSheetSubtitle =>
      'การกู้คืนแบบเต็มจะแทนที่ข้อมูลแอปปัจจุบัน คีย์ API ของตัวแยกวิเคราะห์แบบกำหนดเองจะอยู่ในที่จัดเก็บที่ปลอดภัยและจะไม่ถูกเขียนลงในไฟล์สำรอง';

  @override
  String get restoreBackupFileTitle => 'กู้คืนจากไฟล์ JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'เลือกไฟล์สำรอง Sked แบบเต็ม คุณจะต้องยืนยันก่อนกู้คืน';

  @override
  String get restoreBackupTextTitle => 'วาง JSON สำรอง';

  @override
  String get restoreBackupTextSubtitle =>
      'วางข้อมูลสำรองแบบเต็มและกู้คืนข้อมูลแอปปัจจุบัน';

  @override
  String get shareBackupTitle => 'แชร์ไฟล์สำรอง';

  @override
  String get shareBackupSubtitle =>
      'ส่งออกข้อมูลแอปทั้งหมดเป็น JSON โดยไม่รวมคีย์ API';

  @override
  String get saveBackupTitle => 'บันทึกไฟล์สำรอง';

  @override
  String get saveBackupSubtitle =>
      'บันทึกข้อมูลสำรองของแอปแบบเต็มลงในไฟล์ภายในเครื่อง';

  @override
  String get copyBackupTitle => 'คัดลอกข้อความสำรอง';

  @override
  String get copyBackupSubtitle =>
      'แสดง JSON สำรองแบบเต็มเพื่อให้คุณคัดลอกหรือเก็บไว้ชั่วคราวได้';

  @override
  String get restoreBackupConfirmTitle => 'กู้คืนข้อมูลสำรองแบบเต็มหรือไม่';

  @override
  String get restoreBackupConfirmMessage =>
      'การดำเนินการนี้จะแทนที่ตารางเรียน ตารางเวลาทั่วไป การตั้งค่า และเว็บไซต์โรงเรียนทั้งหมดในปัจจุบัน คีย์ API จะไม่ถูกนำเข้าจากข้อมูลสำรอง โปรดป้อนคีย์อีกครั้งก่อนแยกวิเคราะห์ตารางเรียนอีกครั้ง';

  @override
  String get restoreBackupConfirmAction => 'กู้คืนข้อมูลสำรอง';

  @override
  String get restoreBackupSuccessMessage =>
      'กู้คืนข้อมูลสำรองของแอปแบบเต็มแล้ว ต้องป้อนคีย์ API ของตัวแยกวิเคราะห์อีกครั้ง';

  @override
  String get restoreBackupFailureMessage =>
      'กู้คืนไม่สำเร็จ โปรดตรวจสอบเนื้อหาข้อมูลสำรองแล้วลองอีกครั้ง';

  @override
  String get openSourceLicenses => 'ใบอนุญาตแหล่งเปิด';

  @override
  String get openSourceLicensesDesc =>
      'ดูใบอนุญาตสําหรับการพึ่งพา Flutter และทรัพย์สินไอคอนแอพที่รวม';

  @override
  String get checkForUpdates => 'ตรวจสอบการอัพเดท';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'อยู่ในรุ่นล่าสุดแล้ว ($version)';
  }

  @override
  String get currentVersionLabel => 'รุ่นปัจจุบัน';

  @override
  String get newVersionAvailable => 'มีการอัพเดท';

  @override
  String get latestVersionLabel => 'เวอร์ชันล่าสุด';

  @override
  String get updateContentLabel => 'อัพเดทรายละเอียด';

  @override
  String get officialWebsite => 'เว็บไซต์อย่างเป็นทางการ';

  @override
  String get googlePlay => 'Google เล่น';

  @override
  String get cloudDrive => 'ไดรฟ์คลาวด์';

  @override
  String get ignoreThisVersion => 'ไม่สนใจรุ่นนี้';

  @override
  String get openUpdatesFailed => 'ไม่สามารถเปิดลิงค์การปรับปรุงได้';

  @override
  String get updateCheckFailedTitle => 'การตรวจสอบการอัพเดทล้มเหลว';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'เก็บข้อมูล GitHub';

  @override
  String get openGithubFailed => 'ไม่สามารถเปิดลิงค์คลังข้อมูล GitHub ได้';

  @override
  String get openPrivacyPolicyFailed =>
      'ไม่สามารถเปิดลิงก์นโยบายความเป็นส่วนตัวได้';

  @override
  String get selectPeriodTimeSet => 'เลือกช่วงเวลา';

  @override
  String get newItem => 'ใหม่';

  @override
  String get editPeriodTimeSet => 'แก้ไขช่วงเวลา';

  @override
  String get importTimetableFiles => 'ตารางเวลานําเข้า';

  @override
  String get importTimetableFilesDesc => 'รองรับไฟล์ตารางเวลาหนึ่งหรือหลายไฟล์';

  @override
  String get importTimetableText => 'นำเข้าตารางเวลาจากข้อความ';

  @override
  String get importTimetableTextDesc => 'วางเนื้อหา JSON ตารางเวลาและนำเข้ามัน';

  @override
  String get shareTimetableFiles => 'แบ่งปันไฟล์ตารางเวลา';

  @override
  String get shareTimetableFilesDesc => 'เลือกตารางเวลาหนึ่งหรือมากกว่าก่อน';

  @override
  String get saveTimetableFiles => 'บันทึกไฟล์ตารางเวลา';

  @override
  String get saveTimetableFilesDesc => 'เลือกตารางเวลาหนึ่งหรือมากกว่าก่อน';

  @override
  String get exportTimetableText => 'ส่งออกตารางเวลาเป็นข้อความ';

  @override
  String get exportTimetableTextDesc =>
      'เลือกตารางเวลาหนึ่งหรือมากกว่า จากนั้นคัดลอกเนื้อหา JSON';

  @override
  String get jsonContent => 'เนื้อหา JSON';

  @override
  String get pasteJsonContentHint => 'วางเนื้อหา JSON เพื่อนําเข้า';

  @override
  String get jsonContentEmpty => 'วางเนื้อหา JSON ก่อน';

  @override
  String get copyText => 'คัดลอก';

  @override
  String get copiedToClipboard => 'คัดลอกไปยังคลิปบอร์ด';

  @override
  String get share => 'แบ่งปัน';

  @override
  String get selectTimetablesToExport => 'เลือกตารางเวลาที่จะส่งออก';

  @override
  String get selectTimetablesToImport => 'เลือกตารางเวลาที่จะนำเข้า';

  @override
  String timetableCourseCount(int count) {
    return '$count หลักสูตร';
  }

  @override
  String get importAction => 'นำเข้า';

  @override
  String get importTimetableDialogTitle => 'ตารางเวลานําเข้า';

  @override
  String get chooseImportMethod => 'เลือกวิธีการนำเข้า';

  @override
  String get importAsNewTimetable => 'นำเข้าเป็นตารางเวลาใหม่';

  @override
  String get replaceCurrentTimetable => 'เปลี่ยนตารางเวลาปัจจุบัน';

  @override
  String get importPeriodTimeSetDialogTitle => 'ชุดเวลาในระยะเวลานําเข้า';

  @override
  String get importPeriodTimeSetDialogBody =>
      'ไฟล์นี้มีชุดเวลาระยะเวลาที่รวม คุณต้องการนำเข้าและเชื่อมโยงมันหรือไม่?';

  @override
  String get importBundledPeriodTimeSets => 'นำเข้าและเกี่ยวข้อง';

  @override
  String get discardBundledPeriodTimeSets => 'ทิ้งชุดที่รวม';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'ไม่มีชุดเวลาช่วงเวลาที่มีอยู่ ดังนั้นชุดเวลาช่วงเวลาที่รวมกันไม่สามารถทิ้งได้';

  @override
  String savedToPath(Object path) {
    return 'บันทึกเป็น $path';
  }

  @override
  String get saveCancelled => 'บันทึกถูกยกเลิก';

  @override
  String get fileSaveRestrictedTitle => 'การบันทึกไฟล์ จำกัด';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'ระบบไม่สามารถบันทึกไฟล์ได้ คุณสามารถลองใหม่หรือใช้การแบ่งปันแทน';

  @override
  String get retrySave => 'พยายามบันทึกอีกครั้ง';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'เปิดใช้งานการเข้าถึงไฟล์ในการตั้งค่าระบบ จากนั้นกลับมาและลองส่งออกอีกครั้ง';

  @override
  String get openSettings => 'เปิดการตั้งค่า';

  @override
  String get browserDownloadRestrictedTitle =>
      'การดาวน์โหลดเบราว์เซอร์ถูกจํากัด';

  @override
  String get browserDownloadRestrictedMessage =>
      'เบราว์เซอร์นี้ไม่รองรับการบันทึกโดยตรงไปยังไฟล์ท้องถิ่น ตรวจสอบอนุญาตการดาวน์โหลดเบราว์เซอร์ หรือใช้แชร์ไฟล์แทน';

  @override
  String get switchToShare => 'ใช้แชร์แทน';

  @override
  String get fileSaveFailedTitle => 'บันทึกไฟล์ล้มเหลว';

  @override
  String get fileSaveFailedWindowsMessage =>
      'ไม่สามารถเขียนไปยังเส้นทางปัจจุบันได้ โฟลเดอร์เป้าหมายอาจถูกปกป้อง ไฟล์อาจถูกใช้ หรือเส้นทางอาจไม่สามารถเขียนได้';

  @override
  String get fileSaveFailedGenericMessage =>
      'ระบบไม่สามารถบันทึกไฟล์ได้ คุณสามารถลองอีกครั้ง ตรวจสอบการตั้งค่าระบบ หรือใช้การแบ่งปันไฟล์แทน';

  @override
  String get retryLater => 'ลองอีกครั้งต่อมา';

  @override
  String get exportSwitchedToShare => 'เปลี่ยนไปใช้แบ่งปันไฟล์เพื่อส่งออก';

  @override
  String get saveFailedRetry => 'บันทึกล้มเหลว กรุณาลองอีกครั้งในภายหลัง';

  @override
  String get appInstanceBlockedTitle => 'Sked เปิดอยู่แล้ว';

  @override
  String get appInstanceBlockedMessage =>
      'หน้าต่าง Sked หรือแท็บเบราว์เซอร์อื่นกำลังใช้ข้อมูลในเครื่องของคุณ ปิดหน้าต่างหรือแท็บนั้นแล้วลองอีกครั้ง';

  @override
  String get appInstanceLeaseFailedTitle => 'ข้อมูลในเครื่องไม่พร้อมใช้งาน';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked ไม่สามารถยืนยันการเข้าถึงข้อมูลในเครื่องแต่เพียงผู้เดียวได้ ข้อมูลของคุณยังไม่ถูกเปิดหรือเปลี่ยนแปลง ตรวจสอบสิทธิ์เข้าถึงพื้นที่เก็บข้อมูลแล้วลองอีกครั้ง';

  @override
  String get savingChanges => 'กำลังบันทึกการเปลี่ยนแปลง...';

  @override
  String get showApiKey => 'แสดงคีย์ API';

  @override
  String get hideApiKey => 'ซ่อนคีย์ API';

  @override
  String get importFailedCheckContent =>
      'การนำเข้าล้มเหลว กรุณาตรวจสอบเนื้อหาไฟล์';

  @override
  String get noImportableTimetables => 'ไม่พบตารางเวลาที่ใช้ได้ในไฟล์ที่นำเข้า';

  @override
  String importedTimetablesCount(int count) {
    return 'การนำเข้า $count ตารางเวลา';
  }

  @override
  String get periodTimesTitle => 'ระยะเวลา';

  @override
  String get importExport => 'นำเข้าและส่งออก';

  @override
  String get importPeriodTemplate => 'แม่แบบระยะเวลานําเข้า';

  @override
  String get importPeriodTemplateText => 'นำเข้าเทมเพลตช่วงเวลาจากข้อความ';

  @override
  String get sharePeriodTemplate => 'แม่แบบระยะเวลาแบ่งปัน';

  @override
  String get saveTemplateToFile => 'บันทึกเทมเพลตเป็นไฟล์';

  @override
  String get exportPeriodTemplateText => 'ส่งออกแม่แบบระยะเวลาเป็นข้อความ';

  @override
  String get deletePeriodTimeSet => 'ลบช่วงเวลาที่กำหนดไว้';

  @override
  String get periodTimeSetName => 'ชื่อช่วงเวลา';

  @override
  String get addOnePeriod => 'เพิ่มระยะเวลา';

  @override
  String periodNumberLabel(int index) {
    return 'ระยะเวลา $index';
  }

  @override
  String get deleteThisPeriod => 'ลบระยะเวลานี้';

  @override
  String durationMinutes(int minutes) {
    return 'ระยะเวลา $minutes นาที';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'ช่องว่างจากก่อนหน้านี้ $minutes นาที';
  }

  @override
  String get endTimeMustBeLater => 'เวลาสิ้นสุดต้องช้ากว่าเวลาเริ่มต้น';

  @override
  String get periodOverlapPrevious => 'ช่วงเวลานี้ซ้อนกับช่วงเวลาก่อนหน้านี้';

  @override
  String get periodTimesSaved => 'เวลาระยะเวลาที่บันทึก';

  @override
  String get deletePeriodTimeSetTitle => 'ลบช่วงเวลาที่กำหนดไว้';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'ลบ \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'ช่วงเวลาปัจจุบัน';

  @override
  String importedPeriodTimesCount(int count) {
    return 'นำเข้า $count เวลาระยะเวลา';
  }

  @override
  String get periodFilePermissionTitle => 'จำเป็นต้องได้รับอนุญาตไฟล์';

  @override
  String get androidFilePermissionMessage =>
      'การส่งออก Android ต้องได้รับอนุญาตเข้าถึงไฟล์ ให้อนุญาตในการบันทึกต่อ';

  @override
  String get reauthorize => 'อนุญาตอีกครั้ง';

  @override
  String get permissionPermanentlyDeniedTitle => 'อนุญาตถูกปฏิเสธอย่างถาวร';

  @override
  String get permissionSettingsExportMessage =>
      'เปิดใช้งานการเข้าถึงไฟล์ในการตั้งค่าระบบ จากนั้นกลับมาและลองส่งออกอีกครั้ง';

  @override
  String get privacyPolicyTitle => 'นโยบายความเป็นส่วนตัว';

  @override
  String get privacyPolicyEntryDesc =>
      'เรียนรู้วิธีการที่แอพจัดการกับการจัดเก็บข้อมูลในท้องถิ่น การตั้งค่าเว็บไซต์โรงเรียน การนําเข้า / ส่งออกไฟล์ การวิเคราะห์หน้าเ';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'รุ่นที่ยอมรับ: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked เป็นเครื่องมือตารางเรียนที่เน้นการทำงานในเครื่องเป็นหลัก ตารางเรียน ชุดเวลา และการกำหนดค่าเว็บไซต์โรงเรียนจะถูกเก็บไว้ในอุปกรณ์หรือเบราว์เซอร์ของคุณเท่านั้น และไม่เคยถูกอัปโหลดโดยอัตโนมัติ แอปจะประมวลผลข้อมูลเฉพาะเมื่อคุณเรียกใช้การกระทำอย่างชัดเจน เช่น การนำเข้า การวิเคราะห์หน้าเว็บ การแชร์ หรือการเปิดลิงก์ภายนอก นโยบายความเป็นส่วนตัวฉบับเต็มมีให้ดูทางออนไลน์';

  @override
  String get privacyPolicyLocalStorageTitle => 'การเก็บข้อมูลในท้องถิ่น';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. Custom timetable parser settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'นำเข้าและส่งออก';

  @override
  String get privacyPolicyImportExportBody =>
      'แอพอ่านหรือเขียนไฟล์ JSON ตารางเวลา ไฟล์ JSON ของเว็บไซต์โรงเรียน และไฟล์แม่แบบระยะเวลาเท่านั้นเมื่อคุณเลือกไฟล์หรือเริ่มการส่งออกอย่างชัดเจน การนำเข้าไฟล์เหล่านี้เป็นการดำเนินการในท้องถิ่น เว้นแต่คุณยังเลือกการวิเคราะห์หน้าเว็บ การรับรายชื่อแบบจำลองที่กำหนดเองยังเป็นการกระทําเครือข่ายที่ชัดเจน และติดต่อเพียงจุดสิ้นสุดที่กำหนดเองที่คุณกำหนดค่า';

  @override
  String get privacyPolicySharingTitle => 'การแบ่งปัน';

  @override
  String get privacyPolicySharingBody =>
      'เมื่อคุณใช้การแบ่งปันอย่างชัดเจน แอพจะส่งไฟล์ที่ส่งออกไปยังแผ่นแบ่งปันระบบหรือไปยังแอพเป้าหมายที่คุณเลือก วิธีการจัดการไฟล์นั้นหลังจากนั้นขึ้นอยู่กับแอพหรือบริการเป้าหมายที่คุณเลือก';

  @override
  String get privacyPolicyExternalLinksTitle => 'ลิงค์ภายนอก';

  @override
  String get privacyPolicyExternalLinksBody =>
      'เมื่อคุณเปิดลิงค์ภายนอก เช่น GitHub repository แอพจะส่งการกระทําไปยังเบราว์เซอร์ของคุณหรือแอพพลิเคชันภายนอกอื่น การจัดการข้อมูลหลังจากจุดนั้นจะถูกควบคุมโดยบุคคลที่สามที่คุณเปิด';

  @override
  String get privacyPolicyNoCollectionTitle => 'สิ่งที่แอพไม่รวบรวม';

  @override
  String get privacyPolicyNoCollectionBody =>
      'แอพไม่ต้องใช้บัญชี Sked และไม่เปิดใช้งานการวิเคราะห์ ตัวระบุการโฆษณา หรือการสำรองข้อมูลในเมฆ นอกจากนี้ยังไม่ให้สนามที่เฉพาะสำหรับการเก็บรวบรหัสผ่านบัญชีโรงเรียน ถ้าคุณเข้าสู่เว็บไซต์โรงเรียนภายในแอป การปฏิสัมพันธ์นั้นเกิดขึ้นในหน้าโรงเรียนที่คุณเปิด';

  @override
  String get privacyPolicyFutureFeatureTitle => 'การวิเคราะห์หน้าเว็บ';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'เมื่อคุณใช้นำเข้าหน้าเว็บของโรงเรียนหรือแยกวิเคราะห์ข้อความตารางเรียน / HTML ที่วางไว้ แอปจะเตรียมและล้างเนื้อหาในเครื่องก่อน จากนั้นจึงส่งข้อความตารางเรียน ข้อความหน้าเว็บ หรือเนื้อหา HTML ที่คุณส่ง ชื่อหน้าและ URL ที่เลือกใส่ได้ ภาษาปัจจุบันของแอป และเนื้อหา prompt ของตัวแยกวิเคราะห์ ไปยัง endpoint ที่เข้ากันได้กับ OpenAI ที่คุณกำหนดไว้ การดึงรายการโมเดลก็จะร้องขอไปยัง endpoint เดียวกัน Sked ไม่มี endpoint ตัวแยกวิเคราะห์ในตัว และจะไม่ส่งคำขอแยกวิเคราะห์ไปยัง backend ตัวแยกวิเคราะห์ตารางเรียนที่นักพัฒนาควบคุม endpoint แบบกำหนดเองและบริการต้นทางใด ๆ อาจจัดเก็บ ส่งต่อ จำกัด ลบ หรือประมวลผลข้อมูลด้วยวิธีอื่นตามกฎของผู้ให้บริการที่คุณเลือก หากคุณใช้ http:// Base URL ให้ใช้เฉพาะบนอุปกรณ์ เครือข่าย และบริการ endpoint ที่เชื่อถือได้เท่านั้น เพราะเนื้อหาและคีย์ API อาจไม่ได้รับการปกป้องด้วยการเข้ารหัสระหว่างส่งข้อมูล';

  @override
  String get privacyPolicyUpdatesTitle => 'การปรับปรุงนโยบาย';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'เวอร์ชั่นโยบายความเป็นส่วนตัวปัจจุบันคือ $version. หากเวอร์ชั่นใหม่เปลี่ยนแปลงวิธีการจัดการข้อมูล แอปอาจขอให้คุณอ่านและยอมรับนโยบายที่ปรับปรุงอีกครั้ง';
  }

  @override
  String get privacyGateTitle => 'โปรดยอมรับนโยบายความเป็นส่วนตัวก่อนใช้แอป';

  @override
  String get privacyGateSummaryStorage =>
      'ตารางเวลา ชุดเวลา และการตั้งค่าเว็บไซต์โรงเรียนจะถูกเก็บไว้ในท้องถิ่นเท่านั้น และไม่ถูกอัพโหลดไปยังเซิร์ฟเวอร์ผู้พัฒนาโดยอัตโนม';

  @override
  String get privacyGateSummaryImportExport =>
      'การนำเข้า การส่งออก และการแบ่งปันเกิดขึ้นเพียงเมื่อคุณเริ่มมันอย่างชัดเจน การวิเคราะห์หน้าเว็บไซต์จะส่งเนื้อหาที่บีบอัดที่คุณส่งไปยังจุดท้ายการวิเคราะห์ที่คุณกำหนดค่า และคุณสามารถตรวจสอบตารางเวลาที่ว';

  @override
  String get privacyGateSummaryUpdates =>
      'หากเวอร์ชั่นใหม่เปลี่ยนแปลงวิธีการจัดการข้อมูล แอปอาจขอให้คุณตรวจสอบนโยบายความเป็นส่วนตัวที่ปรับปรุงอีกครั้ง';

  @override
  String get schoolWebImportEntry => 'นำเข้าจากเว็บไซต์โรงเรียน';

  @override
  String get schoolWebImportEntryDesc =>
      'นำเข้าหน้าเวลาปัจจุบันจากเว็บไซต์โรงเรียน';

  @override
  String get schoolSitesManageEntry => 'จัดการเว็บไซต์โรงเรียน';

  @override
  String get schoolSitesManageEntryDesc =>
      'เพิ่ม แก้ไข และลบ URL การเข้าสู่ระบบโรงเรียนด้วยการนําเข้าและส่งออก JSON';

  @override
  String get schoolSitesPageTitle => 'การจัดการสถานที่โรงเรียน';

  @override
  String get schoolSitesImportJson => 'นำเข้า JSON โรงเรียน';

  @override
  String get schoolSitesShareJson => 'แบ่งปันโรงเรียน JSON';

  @override
  String get schoolSitesSaveJson => 'บันทึก JSON โรงเรียน';

  @override
  String get schoolSitesSaved => 'เว็บไซต์โรงเรียนที่บันทึก';

  @override
  String get schoolSitesImported => 'เว็บไซต์โรงเรียนที่นำเข้า';

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
  String get schoolSitesEmpty => 'ยังไม่มีการตั้งค่าเว็บไซต์โรงเรียน';

  @override
  String get schoolSitesNameLabel => 'ชื่อโรงเรียน';

  @override
  String get schoolSitesLoginUrlLabel => 'URL การเข้าสู่ระบบ';

  @override
  String get schoolSitesAdd => 'เพิ่มโรงเรียน';

  @override
  String get schoolSitesEdit => 'แก้ไขโรงเรียน';

  @override
  String get schoolSitesDeleteTitle => 'ลบโรงเรียน';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'ลบ \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'กรอกชื่อโรงเรียนและ URL เข้าสู่ระบบก่อน';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry => 'นำเข้าโดยวางเนื้อหาหน้าตลาดเวลา';

  @override
  String get schoolHtmlImportEntryDesc =>
      'วางรหัสแหล่งหรือเนื้อหาหน้าดิบที่มีข้อมูลตารางเวลาด้วยมือ';

  @override
  String get schoolHtmlImportPageTitle => 'วิเคราะห์ตารางเวลาจากเนื้อหาหน้า';

  @override
  String get schoolHtmlImportUrlLabel => 'URL แหล่ง (ไม่เป็นตัวเลือก)';

  @override
  String get schoolHtmlImportTitleLabel => 'ชื่อหน้า (ตัวเลือก)';

  @override
  String get schoolHtmlImportHtmlLabel => 'เนื้อหาหน้า';

  @override
  String get schoolHtmlImportHtmlHint =>
      'วางรหัสแหล่งหรือเนื้อหาหน้าดิบที่มีข้อมูลตารางเวลาที่นี่';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'เนื้อหาใด ๆ ที่มีข้อมูลตารางเวลาสามารถวิเคราะห์และนำเข้าได้ ไม่ใช่เพียง HTML เท่านั้น';

  @override
  String get schoolHtmlImportCompress => 'เตรียมเนื้อหา';

  @override
  String get schoolHtmlImportCompressed => 'เตรียมเนื้อหาแล้ว';

  @override
  String get schoolHtmlImportCompressFirst => 'เตรียมเนื้อหาก่อน';

  @override
  String get schoolHtmlImportSubmit => 'วิเคราะห์และนำเข้า';

  @override
  String get schoolImportContentTruncated =>
      'หน้านี้ถึงขีดจำกัดการนำเข้าที่ปลอดภัยแล้ว ระบบจะส่งเฉพาะส่วนที่บันทึกไว้ไปวิเคราะห์';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'การวิเคราะห์อาจใช้เวลาสักพัก โปรดรอ';

  @override
  String get schoolHtmlImportEmpty => 'วางหน้า HTML ก่อน';

  @override
  String get schoolHtmlImportReturnToWebPage => 'กลับไปที่หน้าเว็บ';

  @override
  String get schoolWebImportPageTitle => 'การนำเข้าเว็บไซต์โรงเรียน';

  @override
  String get schoolWebImportPreview => 'นำเข้าการดูล่วงหน้า';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count หลักสูตร';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return ' $count ระยะเวลา';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'ชื่อหน้า';

  @override
  String get schoolWebImportParserUsed => 'เครื่องวิเคราะห์';

  @override
  String get schoolWebImportWarnings => 'นำเข้าบันทึก';

  @override
  String get schoolWebImportOpenPageHint =>
      'เข้าสู่เว็บไซต์โรงเรียนในแอป จากนั้นเดินทางไปยังหน้าตารางเวลาด้วยมือ';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'แพลตฟอร์มนี้ยังไม่รองรับการเข้าสู่ระบบเว็บที่ฝังอยู่ กรุณาใช้แพลตฟอร์มที่รองรับ WebView';

  @override
  String get schoolWebImportSelectSchool => 'เลือกโรงเรียน';

  @override
  String get schoolWebImportNoSchools =>
      'ไม่มีการตั้งค่าโรงเรียน ตรวจสอบ school_sites.json ก่อน';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'ล้มเหลวในการโหลดการตั้งค่าโรงเรียน ตรวจสอบรูปแบบไฟล์ JSON';

  @override
  String get schoolWebImportImportCurrentPage => 'นำเข้าหน้าปัจจุบัน';

  @override
  String get schoolWebImportGoBack => 'หน้าก่อนหน้า';

  @override
  String get schoolWebImportLoadingPage => 'กำลังโหลดหน้า…';

  @override
  String get schoolWebImportParsing => 'การวิเคราะห์หน้าปัจจุบัน...';

  @override
  String get schoolWebImportLoadFailed =>
      'การโหลดหน้าล้มเหลว โปรดปรับปรุงหรือลองอีกครั้งในภายหลัง';

  @override
  String get schoolWebImportLoadTimedOut =>
      'การโหลดหน้าถูกหมดเวลา กรุณาปรับปรุงและลองอีกครั้ง';

  @override
  String get schoolWebImportUnknownOrigin => 'ไซต์ที่ไม่รู้จัก';

  @override
  String get schoolWebImportCrossOriginTitle => 'ไปยังไซต์อื่นหรือไม่';

  @override
  String schoolWebImportCrossOriginMessage(Object origin) {
    return 'การลงชื่อเข้าใช้ระบบของโรงเรียนอาจต้องเปิดไซต์อื่น โปรดดำเนินการต่อเฉพาะเมื่อคุณเชื่อถือปลายทางนี้สำหรับเซสชันการนำเข้าปัจจุบัน:\n\n$origin';
  }

  @override
  String get schoolWebImportEmptyPage =>
      'เนื้อหาหน้าปัจจุบันว่างเปล่าและยังไม่สามารถนำเข้าได้';

  @override
  String get schoolWebImportSuccess => 'ตารางเวลาเว็บนำเข้า';

  @override
  String get schoolImportParserSettingsTitle =>
      'การตั้งค่าเครื่องวิเคราะห์ตาราง';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure your own OpenAI-compatible endpoint. HTTP and HTTPS base URLs are supported.';

  @override
  String get schoolImportParserSourceTitle => 'แหล่ง Parser';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'เข้ากันได้กับ OpenAI ที่กำหนดเอง';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'เครื่องวิเคราะห์ที่เข้ากันได้กับ OpenAI ที่กำหนดเอง';

  @override
  String get schoolImportParserCustomPromptTitle => 'โปรมป์ตที่กำหนดเอง';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'แก้ไขโปรมปต์การวิเคราะห์ในตัวที่นี่ การเปลี่ยนแปลงมีผลต่อเครื่องวิเคราะห์ที่เข้ากันได้กับ OpenAI ที่กำหนดเองเท่านั้น';

  @override
  String get schoolImportParserCustomPromptHint =>
      'โปรมป์ตในตัวถูกโหลดที่นี่โดยค่าเริ่มต้น ล้างมันเพื่อกลับไปยังรุ่นในตัว';

  @override
  String get schoolImportParserResetDefaultPrompt => 'รีเซ็ตโปรมป์ตค่าเริ่มต้น';

  @override
  String get schoolImportParserBaseUrl => 'URL ฐาน';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL ต้องเป็น URL แบบ HTTP หรือ HTTPS ที่มีโฮสต์';

  @override
  String get schoolImportParserApiKey => 'คีย์ API';

  @override
  String get schoolImportParserModel => 'แบบ';

  @override
  String get schoolImportParserFetchModels => 'รับรายการรูปแบบ';

  @override
  String get schoolImportParserFetchingModels => 'ไปหารูปแบบ ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'ไม่มีรูปแบบที่ได้รับการคืนโดยจุดสิ้นสุด';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'ไม่สามารถดึงรายการโมเดลได้ โปรดตรวจสอบปลายทางแล้วลองอีกครั้ง';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'รุ่นที่รับ $count';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'ใช้ปลายทาง HTTP ที่ไม่ได้เข้ารหัสหรือไม่';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'คีย์ API และเนื้อหาตารางเรียนอาจถูกอ่านหรือแก้ไขระหว่างการส่ง โปรดดำเนินการต่อเฉพาะเมื่อคุณเชื่อถืออุปกรณ์ เครือข่าย และปลายทางนี้ การอนุญาตนี้มีผลจนกว่าคุณจะปิด Sked';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'การตั้งค่า parser ที่กำหนดเองไม่สมบูรณ์ กรอก URL ฐาน คีย์ API และรูปแบบก่อน';

  @override
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'เครื่องวิเคราะห์: กำหนดเอง ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'ดูนโยบายความเป็นส่วนตัวเต็ม';

  @override
  String get privacyAgreeAndContinue => 'ตกลงและดำเนินการต่อไป';

  @override
  String get privacyDecline => 'ปฏิเสธ';

  @override
  String get privacyDeclineWebHint =>
      'สภาพแวดล้อมเบราว์เซอร์นี้ไม่อนุญาตให้แอพปิดหน้าสำหรับคุณ หากคุณไม่เห็นด้วยโปรดปิดแท็บนี้หรือหน้าต่างด้วยตัวเอง';

  @override
  String get defaultPeriodTimeSetName => 'ระยะเวลาเริ่มต้น';

  @override
  String get periodTimeSetFallbackName => 'ระยะเวลา';

  @override
  String get untitledTimetableName => 'ตารางเวลาที่ไม่มีชื่อ';

  @override
  String get newTimetableName => 'ตารางเวลาใหม่';

  @override
  String get newPeriodTimeSetName => 'กำหนดเวลาใหม่';

  @override
  String get emptyTimetableName => 'ตารางเวลาที่ว่าง';

  @override
  String importedPeriodTimeSetName(Object name) {
    return ' $name ระยะเวลา';
  }

  @override
  String get importFileTypeMismatchMessage => 'ประเภทไฟล์นำเข้าไม่ตรงกัน';

  @override
  String get importFileVersionUnsupportedMessage =>
      'รุ่นไฟล์นำเข้านี้ยังไม่ได้รับการสนับสนุน';

  @override
  String get noPeriodTimesInImportMessage => 'ไม่พบเวลาช่วงเวลาในไฟล์นำเข้า';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'กรุณาเลือกตารางเวลาอย่างน้อย 1 ตาราง';

  @override
  String get noExportableTimetableMessage => 'ไม่มีตารางเวลาในการส่งออก';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'การเปลี่ยนตารางเวลาปัจจุบันสนับสนุนการเลือกตารางเวลาหนึ่งเท่านั้น';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'ไม่มีตารางเวลาปัจจุบันที่จะแทนที่';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'ช่วงเวลานี้ยังคงใช้โดยตารางเวลา $count (s) จัดสรรมันใหม่ก่อนลบ';
  }

  @override
  String get weekdayMonday => 'วันจันทร์';

  @override
  String get weekdayTuesday => 'วันอังคาร';

  @override
  String get weekdayWednesday => 'วันพุธ';

  @override
  String get weekdayThursday => 'วันพฤหัสบดี';

  @override
  String get weekdayFriday => 'วันศุกร์';

  @override
  String get weekdaySaturday => 'วันเสาร์';

  @override
  String get weekdaySunday => 'วันอาทิตย์';

  @override
  String get weekdayShortMonday => 'จันทร์';

  @override
  String get weekdayShortTuesday => 'วันอังคาร';

  @override
  String get weekdayShortWednesday => 'พุธ';

  @override
  String get weekdayShortThursday => 'พฤหัสบดี';

  @override
  String get weekdayShortFriday => 'วันศุกร์';

  @override
  String get weekdayShortSaturday => 'วันเสาร์';

  @override
  String get weekdayShortSunday => 'อาทิตย์';

  @override
  String get monthJanuary => 'มกราคม';

  @override
  String get monthFebruary => 'กุมภาพันธ์';

  @override
  String get monthMarch => 'มีนาคม';

  @override
  String get monthApril => 'เมษายน';

  @override
  String get monthMay => 'พฤษภาคม';

  @override
  String get monthJune => 'มิถุนายน';

  @override
  String get monthJuly => 'กรกฎาคม';

  @override
  String get monthAugust => 'สิงหาคม';

  @override
  String get monthSeptember => 'กันยายน';

  @override
  String get monthOctober => 'ตุลาคม';

  @override
  String get monthNovember => 'พฤศจิกายน';

  @override
  String get monthDecember => 'ธันวาคม';

  @override
  String get semesterWeeksWholeTerm => 'ทั้งภาคศึกษา';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'สัปดาห์ $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'สัปดาห์ $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'เลือกโหมดเริ่มต้น';

  @override
  String get firstLaunchSubtitle =>
      'เลือกพื้นที่ทำงานที่คุณใช้บ่อยที่สุด คุณสามารถสลับโหมดได้ภายหลัง';

  @override
  String get firstLaunchStudentDesc =>
      'จัดการตารางเรียน วิชา สัปดาห์ เวลาเรียน และการนำเข้า';

  @override
  String get firstLaunchGeneralDesc =>
      'จัดการปฏิทิน เหตุการณ์ การแจ้งเตือน และข้อมูล JSON / ICS';

  @override
  String get firstLaunchStartStudent => 'เริ่มด้วยตารางเรียน';

  @override
  String get firstLaunchStartGeneral => 'เริ่มด้วยตารางเวลา';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'เมื่อเลือกพื้นที่ทำงานเริ่มต้น แสดงว่าคุณได้อ่านและยอมรับ';

  @override
  String get firstLaunchPrivacyConsentLink => 'นโยบายความเป็นส่วนตัว';

  @override
  String get firstLaunchPrivacyConsentAfter => 'แล้ว';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => 'วันนี้';

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
      'Toggles for the general schedule view';

  @override
  String get closePopupOnOutsideTap => 'Close popup on tap outside';

  @override
  String get showGridLines => 'Show grid lines';

  @override
  String get generalScheduleImportExport => 'Schedule import & export';

  @override
  String get generalScheduleImportExportDesc =>
      'Import or share general schedules';

  @override
  String get importGeneralSchedules => 'Import schedules';

  @override
  String get importGeneralSchedulesDesc => 'Read schedules from a JSON file';

  @override
  String get shareGeneralSchedules => 'Share schedules';

  @override
  String get shareGeneralSchedulesDesc => 'Share schedules as a JSON file';

  @override
  String get saveGeneralSchedules => 'Save schedules';

  @override
  String get saveGeneralSchedulesDesc => 'Save schedules as a JSON file';

  @override
  String get selectSchedulesToExport => 'Select schedules to export';

  @override
  String get selectSchedulesToImport => 'Select schedules to import';

  @override
  String generalScheduleEventCount(int count) {
    return 'Events: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Imported $count schedules';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Replace current schedule with the imported one?';

  @override
  String get addAsNewSchedule => 'Add as new';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Please select at least one schedule.';

  @override
  String get noExportableScheduleMessage => 'No schedule available to export.';

  @override
  String get noSchedulesInImportMessage => 'Import file contains no schedules.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Choose exactly one schedule to replace the current one.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'No current schedule to replace.';

  @override
  String get calendars => 'Calendars';

  @override
  String get calendar => 'Calendar';

  @override
  String get viewWeek => 'สัปดาห์';

  @override
  String get viewDay => 'วัน';

  @override
  String get viewList => 'List';

  @override
  String get viewMonth => 'Month';

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
  String moreEvents(int count) {
    return '+$count more';
  }

  @override
  String get noMatchingEvents => 'No matching events';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get addCalendar => 'Add calendar';

  @override
  String get newCalendar => 'New calendar';

  @override
  String get hideCalendar => 'Hide calendar';

  @override
  String get showCalendar => 'Show calendar';

  @override
  String get rename => 'Rename';

  @override
  String get renameCalendar => 'Rename calendar';

  @override
  String get name => 'Name';

  @override
  String get deleteCalendar => 'Delete calendar';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteThisOccurrence => 'Delete this';

  @override
  String get deleteFutureOccurrences => 'Delete future';

  @override
  String get deleteAllOccurrences => 'Delete all';

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
  String get importJsonFile => 'Import JSON file';

  @override
  String get pasteJson => 'Paste JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Import calendars from copied JSON';

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
  String get copyJsonDesc => 'Copy selected calendars as JSON text';

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
    return 'Found $count events. Import as a new calendar or replace the active calendar?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Imported $count schedules with $warningCount warnings';
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
  String get hideHomeBottomNavigationBar => 'Hide the home bottom bar';

  @override
  String get hideHomeBottomNavigationBarDesc =>
      'Switch workspaces from Settings after hiding the bar.';

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
  String get generalToolbarWidthCalendarPriority => 'Calendar priority';

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
  String get schoolWebImportSignInConsentTitle =>
      'เปิดหน้าลงชื่อเข้าใช้ของโรงเรียนหรือไม่';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'การลงชื่อเข้าใช้ของโรงเรียนอาจส่งข้อมูลรับรองผ่านแบบฟอร์มหรือการเปลี่ยนเส้นทางของเซิร์ฟเวอร์ไปยังโรงเรียนและผู้ให้บริการลงชื่อเข้าใช้ Android ไม่สามารถหยุดการส่งแต่ละครั้งเพื่อยืนยันปลายทางแยกกันได้ โปรดดำเนินการต่อเฉพาะเมื่อคุณเชื่อถือบริการเหล่านี้สำหรับเซสชันการนำเข้านี้:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'เปิดการลงชื่อเข้าใช้โรงเรียนที่ไม่ปลอดภัยหรือไม่';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'การลงชื่อเข้าใช้โรงเรียนนี้ใช้ HTTP ผู้ที่สามารถเฝ้าดูหรือแก้ไขการเชื่อมต่อนี้อาจอ่านหรือเปลี่ยนข้อมูลรับรองและเนื้อหาหน้าเว็บของคุณได้ โปรดดำเนินการต่อเฉพาะเมื่อคุณยอมรับความเสี่ยงนี้สำหรับ:\n\n$origin';
  }
}
