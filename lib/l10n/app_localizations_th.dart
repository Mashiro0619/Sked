// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'Sked';

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
  String get schoolImportResultEditorTitle => 'แก้ไข JSON';

  @override
  String get schoolImportParsePageTitle => 'วิเคราะห์ตารางเรียน';

  @override
  String get schoolImportParsePageParsing => 'กำลังวิเคราะห์…';

  @override
  String get schoolImportParsePageFailed => 'วิเคราะห์ไม่สำเร็จ';

  @override
  String get schoolImportParseErrorMessage =>
      'ไม่สามารถแยกข้อมูลตารางเรียนได้ โปรดตรวจสอบเนื้อหา การตั้งค่าตัวแยกข้อมูล และการเชื่อมต่อเครือข่าย แล้วลองอีกครั้ง';

  @override
  String get schoolImportParsePageContinue => 'ดำเนินการต่อ';

  @override
  String get schoolImportExpandWarnings => 'ขยายคำเตือนการนำเข้า';

  @override
  String get schoolImportCollapseWarnings => 'ย่อคำเตือนการนำเข้า';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'บางวิชามีการเรียนถึงสัปดาห์ที่ $week';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'แทนที่ตารางเรียนปัจจุบันหรือไม่?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'ตารางเรียนที่นำเข้าจะแทนที่ตารางเรียนปัจจุบัน';

  @override
  String get createTimetable => 'ตารางเวลาใหม่';

  @override
  String get jumpToWeek => 'กระโดดไปสัปดาห์';

  @override
  String get timetable => 'ตารางเวลา';

  @override
  String get themeWorkspaceSchedule => 'ตารางกิจกรรม';

  @override
  String get timetableName => 'ชื่อตารางเวลา';

  @override
  String get timetableNameRequired => 'กรุณาระบุชื่อตารางเรียน';

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
  String get noTimetableMessage => 'สร้างตารางเรียนหรือเลือกวิธีนำเข้า';

  @override
  String get importTimetable => 'ตารางเวลานำเข้า';

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
      'ไม่มีระยะเวลาที่ตรงกับสำหรับเวลาปัจจุบัน แตะเพื่อเลือกด้วยมือ';

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
  String get customFieldsInvalidJson =>
      'กรุณาป้อนออบเจ็กต์ JSON ที่ถูกต้อง หรือล้างข้อมูลในช่องนี้';

  @override
  String get more => 'เพิ่มเติม';

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
  String get settingsSectionAppearance => 'รูปลักษณ์';

  @override
  String get settingsSectionWorkspace => 'พื้นที่ทำงาน';

  @override
  String get settingsSectionAbout => 'เกี่ยวกับ Sked';

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
      'การแสดงวิชา เค้าโครง ท่าทางเปลี่ยนสัปดาห์ และการเพิ่มด่วน';

  @override
  String get showTimetableGridLines => 'แสดงเส้นทางตารางเวลา';

  @override
  String get timetableHorizontalLayoutSection =>
      'การจัดวางแนวนอนและท่าทางสัมผัส';

  @override
  String get fitDaySelectorToWidth => 'ปรับแถบเลือกวันให้พอดีหน้าจอ';

  @override
  String get fitDaySelectorToWidthHint =>
      'แสดงทั้งเจ็ดวันในหน้าจอเมื่อมีพื้นที่เพียงพอ ปิดเพื่อใช้ความกว้างคงที่และเลื่อนในแนวนอน';

  @override
  String get fitWeekColumnsToWidth => 'ปรับคอลัมน์รายสัปดาห์ให้พอดีหน้าจอ';

  @override
  String get enableWeekSwipeNavigation => 'ปัดเพื่อเปลี่ยนสัปดาห์';

  @override
  String get enableWeekSwipeNavigationHint =>
      'ปัดซ้ายหรือขวาเพื่อเปลี่ยนสัปดาห์ เมื่อใช้ความกว้างคงที่ ให้เลื่อนไปถึงขอบก่อนแล้วลากต่อ';

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
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'ภาษา';

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
  String get appBackupTitle => 'App backup and restore';

  @override
  String get appBackupSheetSubtitle =>
      'Choose which objects to back up or restore. Unselected data is kept, and API keys are never exported.';

  @override
  String get restoreBackupFileTitle => 'Restore from backup file';

  @override
  String get restoreBackupFileSubtitle =>
      'Choose a ZIP or legacy JSON backup, then select objects and confirm the restore.';

  @override
  String get restoreBackupTextTitle => 'วาง JSON สำรอง';

  @override
  String get restoreBackupTextSubtitle =>
      'Paste a legacy JSON backup, then select the objects to restore.';

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
      'Show legacy JSON for business data, app preferences and school sites. Chats, files and Agent configuration are excluded.';

  @override
  String get restoreBackupConfirmTitle => 'กู้คืนข้อมูลสำรองแบบเต็มหรือไม่';

  @override
  String get restoreBackupConfirmMessage =>
      'การดำเนินการนี้จะแทนที่ตารางเรียน ตารางเวลาทั่วไป การตั้งค่า และเว็บไซต์โรงเรียนทั้งหมดในปัจจุบัน คีย์ API จะไม่ถูกนำเข้าจากข้อมูลสำรอง โปรดป้อนคีย์อีกครั้งก่อนแยกวิเคราะห์ตารางเรียนอีกครั้ง';

  @override
  String get restoreBackupConfirmAction => 'กู้คืนข้อมูลสำรอง';

  @override
  String get restoreBackupSuccessMessage =>
      'กู้คืนข้อมูลสำรองของแอปแบบเต็มแล้ว ต้องป้อนคีย์ AI API อีกครั้ง';

  @override
  String get restoreBackupFailureMessage =>
      'กู้คืนไม่สำเร็จ โปรดตรวจสอบเนื้อหาข้อมูลสำรองแล้วลองอีกครั้ง';

  @override
  String get openSourceLicenses => 'ใบอนุญาตแหล่งเปิด';

  @override
  String get openSourceLicensesDesc =>
      'ดูใบอนุญาตสำหรับการพึ่งพา Flutter และทรัพย์สินไอคอนแอพที่รวม';

  @override
  String get checkForUpdates => 'ตรวจสอบการอัพเดท';

  @override
  String get includePrereleaseUpdates => 'รับการอัปเดตเวอร์ชันก่อนเผยแพร่';

  @override
  String get includePrereleaseUpdatesDesc =>
      'รวมเวอร์ชัน Alpha, Beta และ RC ซึ่งอาจไม่เสถียร เมื่อปิดจะเสนอเฉพาะเวอร์ชันเสถียรเท่านั้น';

  @override
  String get currentVersionLabel => 'รุ่นปัจจุบัน';

  @override
  String get newVersionAvailable => 'มีการอัพเดท';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get ignoreThisVersion => 'ไม่สนใจรุ่นนี้';

  @override
  String get openUpdatesFailed => 'ไม่สามารถเปิดลิงค์การปรับปรุงได้';

  @override
  String get updateCheckFailedTitle => 'การตรวจสอบการอัพเดทล้มเหลว';

  @override
  String get githubRepository => 'เก็บข้อมูล GitHub';

  @override
  String get googlePlayStoreDesc => 'ดู Sked บน Google Play';

  @override
  String get openGooglePlayFailed => 'ไม่สามารถเปิด Google Play ได้';

  @override
  String get microsoftStoreDesc => 'ดู Sked ใน Microsoft Store';

  @override
  String get openMicrosoftStoreFailed => 'ไม่สามารถเปิด Microsoft Store ได้';

  @override
  String get starSkedOnGithub => 'ให้ดาว Sked บน GitHub!';

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
  String get importTimetableFiles => 'ตารางเวลานำเข้า';

  @override
  String get importTimetableFilesDesc => 'รองรับไฟล์ตารางเวลาหนึ่งหรือหลายไฟล์';

  @override
  String get importTimetableText => 'Import timetable from text';

  @override
  String get importTimetableTextDesc =>
      'Import timetable JSON directly, or continue with Agent to organize other text.';

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
  String get pasteJsonContentHint => 'วางเนื้อหา JSON เพื่อนำเข้า';

  @override
  String get jsonContentEmpty => 'วางเนื้อหา JSON ก่อน';

  @override
  String get copyText => 'คัดลอก';

  @override
  String get copiedToClipboard => 'คัดลอกไปยังคลิปบอร์ด';

  @override
  String get copyFailed => 'Could not copy. Please try again.';

  @override
  String get share => 'แบ่งปัน';

  @override
  String get selectTimetablesToExport => 'เลือกตารางเวลาที่จะส่งออก';

  @override
  String get selectTimetablesToImport => 'เลือกตารางเวลาที่จะนำเข้า';

  @override
  String get studentDayNextCourse => 'Next course';

  @override
  String get studentDayNoMoreCourses =>
      'No later courses in this timetable\'s semester.';

  @override
  String get studentDayEmpty => 'วันนี้ไม่มีวิชาเรียน';

  @override
  String timetableCourseCount(int count) {
    return '$count หลักสูตร';
  }

  @override
  String get importAction => 'นำเข้า';

  @override
  String get importTimetableDialogTitle => 'ตารางเวลานำเข้า';

  @override
  String get chooseImportMethod => 'เลือกวิธีการนำเข้า';

  @override
  String get importAsNewTimetable => 'นำเข้าเป็นตารางเวลาใหม่';

  @override
  String get replaceCurrentTimetable => 'เปลี่ยนตารางเวลาปัจจุบัน';

  @override
  String get importPeriodTimeSetDialogTitle => 'ชุดเวลาในระยะเวลานำเข้า';

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
      'การดาวน์โหลดเบราว์เซอร์ถูกจำกัด';

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
  String get periodTimesUnsavedExitTitle => 'ยังไม่ได้บันทึกการเปลี่ยนแปลง';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'ไม่สามารถบันทึกการเปลี่ยนแปลงเวลาคาบเรียนล่าสุดได้ คุณสามารถลองอีกครั้ง แก้ไขต่อ หรือทิ้งการเปลี่ยนแปลง';

  @override
  String get periodTimesInvalidExitMessage =>
      'เวลาคาบเรียนบางรายการไม่ถูกต้อง โปรดแก้ไขก่อนบันทึก หรือทิ้งการเปลี่ยนแปลงแล้วออก';

  @override
  String get discardChangesAndExit => 'ทิ้งการเปลี่ยนแปลงและออก';

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
  String get importPeriodTemplate => 'แม่แบบระยะเวลานำเข้า';

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
      'ดูวิธีจัดการข้อมูลในเครื่อง การนำเข้าและส่งออก คำขอเครือข่ายแบบเลือกใช้ และลิงก์ภายนอก';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'รุ่นที่ยอมรับ: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked เป็นเครื่องมือตารางเรียนที่ให้ความสำคัญกับการจัดเก็บข้อมูลในเครื่อง ตารางเรียน กำหนดการทั่วไป ชุดเวลาคาบเรียน และการตั้งค่าเว็บไซต์โรงเรียนจะเก็บไว้ในอุปกรณ์หรือเบราว์เซอร์ของคุณเท่านั้น และจะไม่อัปโหลดโดยอัตโนมัติ แอปจะประมวลผลข้อมูลเมื่อคุณเริ่มดำเนินการอย่างชัดเจน เช่น การนำเข้า การแยกวิเคราะห์ข้อความตารางเรียน / HTML การนำเข้าจากหน้าเว็บไซต์โรงเรียน การแชร์ หรือการเปิดลิงก์ภายนอกเท่านั้น นโยบายความเป็นส่วนตัวฉบับเต็มมีให้อ่านทางออนไลน์';

  @override
  String get privacyGateTitle => 'โปรดยอมรับนโยบายความเป็นส่วนตัวก่อนใช้แอป';

  @override
  String get privacyGateSummaryStorage =>
      'ตารางเรียน กำหนดการทั่วไป ชุดเวลาคาบเรียน และการตั้งค่าเว็บไซต์โรงเรียนจะเก็บไว้ในเครื่องเท่านั้น และจะไม่อัปโหลดไปยังเซิร์ฟเวอร์ของผู้พัฒนาโดยอัตโนมัติ';

  @override
  String get privacyGateSummaryImportExport =>
      'Imports, exports, backups, and sharing happen when you request them. Backups can include chats and files you select; API keys are excluded. When you use Agent, your messages, attachments, and task-related app data returned by tools are sent to your configured API service.';

  @override
  String get privacyGateSummaryUpdates =>
      'หากเวอร์ชั่นใหม่เปลี่ยนแปลงวิธีการจัดการข้อมูล แอปอาจขอให้คุณตรวจสอบนโยบายความเป็นส่วนตัวที่ปรับปรุงอีกครั้ง';

  @override
  String get schoolWebImportEntry => 'นำเข้าจากเว็บไซต์โรงเรียน';

  @override
  String get schoolWebImportEntryDesc =>
      'นำเข้าหน้าเวลาปัจจุบันจากเว็บไซต์โรงเรียน';

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
  String get schoolSitesImportPreviewTitle =>
      'ตรวจสอบการนำเข้าเว็บไซต์สถานศึกษา';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return 'เว็บไซต์ที่ใช้ได้ $validCount แห่ง รายการที่ไม่ถูกต้อง $invalidCount รายการ';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'รายการเว็บไซต์สถานศึกษาในไฟล์นี้ว่างเปล่า';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'รายการที่ $position ไม่ถูกต้องและจะถูกข้าม';
  }

  @override
  String get schoolSitesImportMerge => 'รวม';

  @override
  String get schoolSitesImportReplace => 'แทนที่';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'แทนที่เว็บไซต์สถานศึกษาปัจจุบันหรือไม่?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'การดำเนินการนี้จะลบเว็บไซต์ปัจจุบัน $currentCount แห่ง และบันทึกเว็บไซต์ที่นำเข้า $importedCount แห่ง การดำเนินการนี้ไม่สามารถยกเลิกย้อนหลังได้';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'ต้องกู้คืนข้อมูลเว็บไซต์สถานศึกษา';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked ไม่สามารถอ่านไฟล์เว็บไซต์สถานศึกษาหรือข้อมูลสำรองได้ ระบบได้สร้างสำเนาที่ได้รับการป้องกันไว้ก่อนระงับการเขียนข้อมูล';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'พื้นที่จัดเก็บเว็บไซต์สถานศึกษาไม่พร้อมใช้งาน';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'ขณะนี้ Sked ไม่สามารถเข้าถึงพื้นที่จัดเก็บเว็บไซต์สถานศึกษาได้ โปรดตรวจสอบสิทธิ์การเข้าถึงหรือความพร้อมของอุปกรณ์แล้วลองอีกครั้ง ข้อมูลเว็บไซต์ปัจจุบันจะไม่ถูกเขียนทับ';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'ไฟล์กู้คืนหรือตำแหน่งจัดเก็บที่มีปัญหาแสดงอยู่ด้านล่าง โปรดอย่าเปลี่ยนแปลงไฟล์จนกว่าจะกู้คืนรายการเว็บไซต์เสร็จ';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'เริ่มโดยไม่มีเว็บไซต์สถานศึกษา';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'เริ่มด้วยรายการเว็บไซต์สถานศึกษาที่ว่างเปล่าหรือไม่?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'สำเนาที่ได้รับการป้องกันจะยังคงอยู่ แต่ Sked จะสร้างไฟล์เว็บไซต์สถานศึกษาใหม่ที่ว่างเปล่า ดำเนินการต่อเฉพาะเมื่อคุณไม่ต้องการลองกู้คืนอีกครั้งก่อน';

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
  String get schoolWebImportWarnings => 'นำเข้าบันทึก';

  @override
  String get schoolWebImportParserDetails => 'รายละเอียดการแยกวิเคราะห์';

  @override
  String get schoolWebImportExpandParserDetails =>
      'ขยายรายละเอียดการแยกวิเคราะห์';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'ยุบรายละเอียดการแยกวิเคราะห์';

  @override
  String get schoolWebImportOpenPageHint =>
      'เข้าสู่เว็บไซต์โรงเรียนในแอป จากนั้นเดินทางไปยังหน้าตารางเวลาด้วยมือ';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'แพลตฟอร์มนี้ยังไม่รองรับการเข้าสู่ระบบเว็บที่ฝังอยู่ กรุณาใช้แพลตฟอร์มที่รองรับ WebView';

  @override
  String get schoolWebImportNoSchools => 'ยังไม่มีโรงเรียนให้เลือก';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'โหลดการตั้งค่าโรงเรียนไม่สำเร็จ โปรดลองอีกครั้ง';

  @override
  String get schoolWebImportImportCurrentPage => 'นำเข้าหน้าปัจจุบัน';

  @override
  String get schoolWebImportLoadFailed =>
      'การโหลดหน้าล้มเหลว โปรดปรับปรุงหรือลองอีกครั้งในภายหลัง';

  @override
  String get schoolWebImportUnknownOrigin => 'ไซต์ที่ไม่รู้จัก';

  @override
  String get schoolWebImportExitTitle => 'ออกจากเบราว์เซอร์ใช่ไหม';

  @override
  String get schoolWebImportExitMessage =>
      'หน้านี้จะปิดลง สิ่งที่คุณยังไม่ได้นำเข้าจะสูญหาย';

  @override
  String get schoolWebImportExitConfirm => 'ออก';

  @override
  String get schoolWebImportEmptyPage =>
      'เนื้อหาหน้าปัจจุบันว่างเปล่าและยังไม่สามารถนำเข้าได้';

  @override
  String get schoolWebImportSuccess => 'ตารางเวลาเว็บนำเข้า';

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
  String get schoolImportParserSettingsTitle => 'API วิเคราะห์ตารางเรียน';

  @override
  String get schoolImportParserSettingsDesc =>
      'ตั้งค่า API ที่เข้ากันได้กับ OpenAI สำหรับนำเข้าตารางเรียน ไม่ใช่การตั้งค่าผู้ช่วยแชต';

  @override
  String get schoolImportParserSourceTitle => 'แหล่ง Parser';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'เข้ากันได้กับ OpenAI ที่กำหนดเอง';

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
      'คีย์ API ที่กำหนดเองจะเก็บผ่านระบบจัดเก็บที่ปลอดภัยของแพลตฟอร์มหากมีให้ใช้ ใช้ข้อมูลรับรองของตัวแยกวิเคราะห์และปลายทาง HTTP ที่กำหนดเองเฉพาะบนอุปกรณ์ เบราว์เซอร์ และเครือข่ายที่คุณเชื่อถือเท่านั้น';

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
  String get clearAppData => 'ล้างข้อมูล';

  @override
  String get clearAppDataDesc =>
      'ลบข้อมูล Sked ทั้งหมดในเครื่องอย่างถาวรแล้วออกจากแอป';

  @override
  String get clearAppDataConfirmTitle => 'ล้างข้อมูล Sked ทั้งหมดหรือไม่?';

  @override
  String get clearAppDataConfirmMessage =>
      'การดำเนินการนี้จะลบตารางเรียน ตารางกิจกรรม การตั้งค่า เว็บไซต์สถานศึกษา ข้อมูลสำรองในเครื่อง สำเนากู้คืน และคีย์ AI API อย่างถาวร แล้วออกจาก Sked ไฟล์ที่คุณส่งออกไปยังที่อื่นจะไม่ถูกลบ การดำเนินการนี้ไม่สามารถยกเลิกย้อนหลังได้';

  @override
  String get clearAppDataAction => 'ล้างข้อมูลและออก';

  @override
  String get clearAppDataFailed =>
      'ไม่สามารถล้างข้อมูลทั้งหมดในเครื่องได้ Sked จะยังเปิดอยู่เพื่อให้คุณลองอีกครั้ง';

  @override
  String get clearAppDataExitFailed =>
      'ล้างข้อมูลในเครื่องแล้ว แต่ Sked ไม่สามารถออกได้ โปรดปิดแอปด้วยตนเองก่อนใช้งานอีกครั้ง';

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
      'ตารางเรียนที่เลือกไว้เพื่อแทนที่ไม่พร้อมใช้งาน โปรดเลือกอีกครั้ง';

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
  String get generalSchedule => 'ตารางกิจกรรมทั่วไป';

  @override
  String get studentTimetable => 'ตารางเรียน';

  @override
  String get firstLaunchTitle => 'เลือกพื้นที่ทำงานที่จะเปิดใช้งาน';

  @override
  String get firstLaunchSubtitle =>
      'ใช้ตารางเรียน กำหนดการ หรือทั้งสองอย่าง และเปลี่ยนตัวเลือกได้ภายหลังในการตั้งค่า';

  @override
  String get firstLaunchStudentDesc =>
      'จัดการตารางเรียน วิชา สัปดาห์ เวลาเรียน และการนำเข้า';

  @override
  String get firstLaunchGeneralDesc =>
      'จัดการหมวดหมู่ เหตุการณ์ การแจ้งเตือน และข้อมูล JSON / ICS';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'เมื่อเลือกพื้นที่ทำงาน แสดงว่าคุณได้อ่านและยอมรับ';

  @override
  String get firstLaunchPrivacyConsentLink => 'นโยบายความเป็นส่วนตัว';

  @override
  String get firstLaunchPrivacyConsentAfter => 'แล้ว';

  @override
  String get switchMode => 'สลับโหมด';

  @override
  String get switchToStudentTimetable => 'สลับไปที่ตารางเรียน';

  @override
  String get today => 'วันนี้';

  @override
  String get addEvent => 'เพิ่มกิจกรรม';

  @override
  String get editEvent => 'แก้ไขกิจกรรม';

  @override
  String get eventTitle => 'ชื่อกิจกรรม';

  @override
  String get eventTitleRequired => 'กรุณาระบุชื่อกิจกรรม';

  @override
  String get eventStartTime => 'เวลาเริ่ม';

  @override
  String get eventEndTime => 'เวลาสิ้นสุด';

  @override
  String get eventDate => 'วันที่';

  @override
  String get eventTime => 'เวลา';

  @override
  String get eventNotes => 'บันทึกย่อ';

  @override
  String get eventColor => 'สี';

  @override
  String get eventRecurrence => 'การทำซ้ำ';

  @override
  String get recurrenceNone => 'ไม่ทำซ้ำ';

  @override
  String get recurrenceWeekly => 'ทุกสัปดาห์';

  @override
  String get recurrenceEndDate => 'วันที่สิ้นสุด';

  @override
  String get repeatsWeekly => 'ทำซ้ำทุกสัปดาห์';

  @override
  String recurrenceUntil(Object date) {
    return 'ถึง $date';
  }

  @override
  String get switchToGeneralSchedule => 'สลับไปที่ตารางกิจกรรมทั่วไป';

  @override
  String get generalDisplaySettings => 'การตั้งค่าการแสดงผลทั่วไป';

  @override
  String get generalDisplaySettingsDesc =>
      'มุมมอง แถบเครื่องมือ รูปแบบวันที่ และการเพิ่มด่วน';

  @override
  String get closePopupOnOutsideTap => 'ปิดป๊อปอัปเมื่อแตะด้านนอก';

  @override
  String get showGridLines => 'แสดงเส้นตาราง';

  @override
  String get generalScheduleImportExport => 'นำเข้าและส่งออกหมวดหมู่';

  @override
  String get generalScheduleImportExportDesc =>
      'นำเข้าหรือแชร์หมวดหมู่ตารางกิจกรรม';

  @override
  String get importGeneralSchedules => 'นำเข้าหมวดหมู่';

  @override
  String get importGeneralSchedulesDesc => 'อ่านหมวดหมู่จากไฟล์ JSON';

  @override
  String get shareGeneralSchedules => 'แชร์หมวดหมู่';

  @override
  String get shareGeneralSchedulesDesc => 'แชร์หมวดหมู่เป็นไฟล์ JSON';

  @override
  String get saveGeneralSchedules => 'บันทึกหมวดหมู่';

  @override
  String get saveGeneralSchedulesDesc => 'บันทึกหมวดหมู่เป็นไฟล์ JSON';

  @override
  String get selectSchedulesToExport => 'เลือกหมวดหมู่ที่จะส่งออก';

  @override
  String get selectSchedulesToImport => 'เลือกหมวดหมู่ที่จะนำเข้า';

  @override
  String generalScheduleEventCount(int count) {
    return 'กิจกรรม: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'นำเข้าแล้ว $count หมวดหมู่';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'ต้องการเพิ่มข้อมูลที่นำเข้าเป็นหมวดหมู่ใหม่ หรือแทนที่หมวดหมู่ที่มีอยู่?';

  @override
  String get addAsNewSchedule => 'เพิ่มเป็นหมวดหมู่ใหม่';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'โปรดเลือกอย่างน้อยหนึ่งหมวดหมู่';

  @override
  String get noExportableScheduleMessage => 'ไม่มีหมวดหมู่ที่ส่งออกได้';

  @override
  String get noSchedulesInImportMessage => 'ไฟล์นำเข้าไม่มีหมวดหมู่';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'เลือกหมวดหมู่ที่นำเข้าเพียงหนึ่งหมวดหมู่สำหรับการแทนที่';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'หมวดหมู่เป้าหมายที่เลือกไม่พร้อมใช้งาน';

  @override
  String get calendars => 'หมวดหมู่';

  @override
  String get calendar => 'หมวดหมู่';

  @override
  String get viewWeek => 'สัปดาห์';

  @override
  String get viewDay => 'วัน';

  @override
  String get viewList => 'รายการ';

  @override
  String get viewMonth => 'เดือน';

  @override
  String visibleCategoryCount(int count) {
    return '$count หมวดหมู่';
  }

  @override
  String get noVisibleCategories => 'ไม่มีหมวดหมู่ที่แสดงอยู่';

  @override
  String get selectCategoryToReplace => 'เลือกหมวดหมู่ที่จะแทนที่';

  @override
  String get replaceCategory => 'แทนที่หมวดหมู่';

  @override
  String get deleteEventTitle => 'ลบกิจกรรม';

  @override
  String get deleteEventConfirmation => 'กิจกรรมนี้จะถูกลบอย่างถาวร';

  @override
  String get deleteRecurringEventTitle => 'ลบกิจกรรมที่เกิดซ้ำ';

  @override
  String get eventDuplicated => 'ทำสำเนากิจกรรมแล้ว';

  @override
  String get allDay => 'ทั้งวัน';

  @override
  String get collapseAllDayTimeline => 'ย่อกิจกรรมทั้งวัน';

  @override
  String get expandAllDayTimeline => 'ขยายกิจกรรมทั้งวัน';

  @override
  String allDayEventsCount(int count) {
    return 'กิจกรรมทั้งวัน $count รายการ';
  }

  @override
  String moreEvents(int count) {
    return '+อีก $count';
  }

  @override
  String get noMatchingEvents => 'ไม่พบกิจกรรมที่ตรงกัน';

  @override
  String get noUpcomingEvents => 'ไม่มีกิจกรรมที่กำลังจะมาถึง';

  @override
  String get addCalendar => 'เพิ่มหมวดหมู่';

  @override
  String get newCalendar => 'หมวดหมู่ใหม่';

  @override
  String get hideCalendar => 'ซ่อนหมวดหมู่';

  @override
  String get showCalendar => 'แสดงหมวดหมู่';

  @override
  String get rename => 'เปลี่ยนชื่อ';

  @override
  String get renameCalendar => 'เปลี่ยนชื่อหมวดหมู่';

  @override
  String get name => 'ชื่อ';

  @override
  String get deleteCalendar => 'ลบหมวดหมู่';

  @override
  String deleteCalendarMessage(Object name) {
    return 'ลบ “$name” หรือไม่?';
  }

  @override
  String get deleteThisOccurrence => 'ลบครั้งนี้';

  @override
  String get deleteFutureOccurrences => 'ลบครั้งนี้และครั้งถัดไปทั้งหมด';

  @override
  String get deleteAllOccurrences => 'ลบทั้งชุด';

  @override
  String get duplicateEvent => 'ทำสำเนา';

  @override
  String get repeatsDaily => 'ทำซ้ำทุกวัน';

  @override
  String get repeatsMonthly => 'ทำซ้ำทุกเดือน';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'ทำซ้ำทุก $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count ครั้ง';
  }

  @override
  String get recurrenceDaily => 'ทุกวัน';

  @override
  String get recurrenceMonthly => 'ทุกเดือน';

  @override
  String get recurrenceCustom => 'กำหนดเอง';

  @override
  String get recurrenceEvery => 'ทุก';

  @override
  String get recurrenceUnit => 'หน่วย';

  @override
  String get recurrenceDays => 'วัน';

  @override
  String get recurrenceWeeks => 'สัปดาห์';

  @override
  String get recurrenceMonths => 'เดือน';

  @override
  String get recurrenceRepeatCount => 'จำนวนครั้งที่ทำซ้ำ';

  @override
  String get recurrenceNoLimit => 'ไม่จำกัด';

  @override
  String get recurrencePositiveNumber => 'กรุณาระบุจำนวนที่มากกว่าศูนย์';

  @override
  String get clearEndDate => 'ล้างวันที่สิ้นสุด';

  @override
  String get pickDate => 'เลือกวันที่';

  @override
  String get pickTime => 'เลือกเวลา';

  @override
  String get reminder => 'การแจ้งเตือน';

  @override
  String get reminderAtStart => 'เมื่อเริ่ม';

  @override
  String reminderMinutesBefore(int minutes) {
    return 'ก่อน $minutes นาที';
  }

  @override
  String get reminderHourBefore => 'ก่อน 1 ชั่วโมง';

  @override
  String get reminderDayBefore => 'ก่อน 1 วัน';

  @override
  String get markReminderHandled => 'ทำเครื่องหมายว่าจัดการแล้ว';

  @override
  String get restoreReminder => 'กู้คืนการเตือนในแอป';

  @override
  String get reminderHandled => 'ทำเครื่องหมายการเตือนในแอปว่าจัดการแล้ว';

  @override
  String get reminderRestored => 'กู้คืนการเตือนในแอปแล้ว';

  @override
  String get reminderUpcoming => 'กำลังจะมาถึง';

  @override
  String get generalFitWeekColumnsToWidth => 'ปรับมุมมองสัปดาห์ให้พอดีหน้าจอ';

  @override
  String get showWeekends => 'แสดงวันเสาร์และอาทิตย์';

  @override
  String get startHour => 'ชั่วโมงเริ่มต้น';

  @override
  String get endHour => 'ชั่วโมงสิ้นสุด';

  @override
  String get timeGridDensity => 'ความถี่ของเส้นตารางเวลา';

  @override
  String get timeGridHourHeight => 'ความสูงของแถวต่อชั่วโมง';

  @override
  String get timeGridHourHeightHint =>
      'ปรับสัดส่วนแนวตั้งของมุมมองรายวันและรายสัปดาห์ โดยไม่เปลี่ยนช่วงเส้นตาราง 15, 30 หรือ 60 นาที';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'นำเข้าไฟล์ JSON';

  @override
  String get pasteJson => 'วาง JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'นำเข้าหมวดหมู่จาก JSON ที่คัดลอกไว้';

  @override
  String get importIcsFile => 'นำเข้าไฟล์ ICS';

  @override
  String get importIcsFileDesc => 'อ่านกิจกรรมจากไฟล์ปฏิทิน .ics';

  @override
  String get pasteIcs => 'วาง ICS';

  @override
  String get pasteIcsDesc => 'นำเข้ากิจกรรมจากข้อความปฏิทินที่คัดลอกไว้';

  @override
  String get copyJson => 'คัดลอก JSON';

  @override
  String get copyJsonDesc => 'คัดลอกหมวดหมู่ที่เลือกเป็นข้อความ JSON';

  @override
  String get shareIcs => 'แชร์ ICS';

  @override
  String get shareIcsDesc => 'แชร์หมวดหมู่ที่เลือกเป็น .ics';

  @override
  String get saveIcs => 'บันทึก ICS';

  @override
  String get saveIcsDesc => 'บันทึกหมวดหมู่ที่เลือกเป็น .ics';

  @override
  String get copyIcs => 'คัดลอก ICS';

  @override
  String get copyIcsDesc => 'คัดลอกหมวดหมู่ที่เลือกเป็นข้อความ ICS';

  @override
  String get importIcs => 'นำเข้า ICS';

  @override
  String get icsContent => 'เนื้อหา ICS';

  @override
  String get pasteIcsContentHint => 'วางเนื้อหา BEGIN:VCALENDAR ที่นี่';

  @override
  String get icsReminderExportTitle => 'การส่งออก ICS ไม่รวมการแจ้งเตือน';

  @override
  String get icsReminderExportMessage =>
      'การแจ้งเตือนจะไม่รวมอยู่ใน ICS ที่ส่งออก เลือก JSON เพื่อเก็บการตั้งค่าการแจ้งเตือนไว้';

  @override
  String get icsReminderExportJsonAction => 'ส่งออก JSON';

  @override
  String get icsReminderExportContinueAction => 'ดำเนินการต่อด้วย ICS';

  @override
  String get icsReminderImportNotice =>
      'การแจ้งเตือนของกิจกรรมที่นำเข้าจาก ICS จะถูกปิด ใช้ JSON เพื่อคืนค่าการตั้งค่าการแจ้งเตือน';

  @override
  String get icsReminderReplaceTitle => 'แทนที่กิจกรรมและการแจ้งเตือนหรือไม่?';

  @override
  String icsReminderReplaceMessage(String calendar) {
    return 'การแทนที่ “$calendar” ด้วยกิจกรรมจาก ICS จะเขียนทับกิจกรรมในหมวดหมู่นี้และปิดการแจ้งเตือนของกิจกรรมเหล่านั้น ยกเลิกเพื่อส่งออกข้อมูลสำรองเป็น JSON ก่อน หรือย้อนกลับไปเพิ่มหมวดหมู่ใหม่แทน';
  }

  @override
  String importIcsPreviewPrompt(int count) {
    return 'พบ $count กิจกรรม ต้องการเพิ่มเป็นหมวดหมู่ใหม่หรือแทนที่หมวดหมู่ที่มีอยู่?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'นำเข้าแล้ว $count หมวดหมู่ พร้อมคำเตือน $warningCount รายการ';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'ข้ามกิจกรรมที่ไม่มีเวลาเริ่มแล้ว';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'ข้ามกิจกรรมที่ใช้รูปแบบเวลาเริ่มที่ไม่รองรับแล้ว';

  @override
  String get importWarningAdjustedEnd =>
      'ปรับกิจกรรมที่เวลาสิ้นสุดไม่อยู่หลังเวลาเริ่มแล้ว';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'ละเว้นฟิลด์ ICS ที่ไม่รองรับแล้ว: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'ละเว้นความถี่การทำซ้ำที่ไม่รองรับ: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs => 'เลือกหมวดหมู่ที่จะคัดลอกเป็น ICS';

  @override
  String get selectCalendarsToExportIcs => 'เลือกหมวดหมู่ที่จะส่งออกเป็น ICS';

  @override
  String get exportIcsText => 'ส่งออกข้อความ ICS';

  @override
  String get exportJsonText => 'ส่งออกข้อความ JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'กู้คืนข้อมูลแอปจากข้อมูลสำรองก่อนหน้าแล้ว เนื่องจากโหลดไฟล์หลักไม่สำเร็จ';

  @override
  String get dataBackupRestoreFailedNotice =>
      'ไฟล์ข้อมูลหลักและข้อมูลสำรองเสียหายทั้งคู่ ขณะนี้แอปเริ่มต้นด้วยข้อมูลใหม่';

  @override
  String get dataRecoveryCorruptTitle => 'ต้องกู้คืนข้อมูลของคุณ';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked ไม่สามารถอ่านไฟล์ข้อมูลหลักหรือข้อมูลสำรองได้ ระบบได้สร้างสำเนาที่ได้รับการป้องกันไว้ก่อนระงับการเขียนข้อมูล';

  @override
  String get dataRecoveryIoFailureTitle => 'พื้นที่จัดเก็บไม่พร้อมใช้งาน';

  @override
  String get dataRecoveryIoFailureMessage =>
      'ขณะนี้ Sked ไม่สามารถเข้าถึงพื้นที่จัดเก็บในเครื่องได้ โปรดตรวจสอบสิทธิ์การเข้าถึงหรือความพร้อมของอุปกรณ์แล้วลองอีกครั้ง ข้อมูลเดิมจะไม่ถูกเขียนทับ';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'อัปเดต Sked เพื่อเปิดข้อมูลนี้';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'ข้อมูลนี้สร้างโดย Sked เวอร์ชันใหม่กว่า โปรดอัปเดตแอปก่อนลองอีกครั้ง การเริ่มด้วยข้อมูลใหม่ถูกปิดไว้เพื่อปกป้องข้อมูลของคุณ';

  @override
  String get dataRecoveryRetryAction => 'ลองอีกครั้ง';

  @override
  String get dataRecoveryArtifactsHint =>
      'ไฟล์กู้คืนหรือตำแหน่งจัดเก็บที่มีปัญหาแสดงอยู่ด้านล่าง โปรดอย่าเปลี่ยนแปลงไฟล์จนกว่าจะกู้คืนข้อมูลเสร็จ';

  @override
  String get dataRecoveryArtifactsAction => 'แสดงไฟล์และตำแหน่งกู้คืน';

  @override
  String get dataRecoveryStartFreshAction => 'เริ่มด้วยข้อมูลใหม่';

  @override
  String get dataRecoveryStartFreshConfirmTitle =>
      'เริ่มด้วยข้อมูลใหม่หรือไม่?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'สำเนาที่ได้รับการป้องกันจะยังคงอยู่ แต่ Sked จะสร้างไฟล์ข้อมูลในเครื่องใหม่ ดำเนินการต่อเฉพาะเมื่อคุณไม่ต้องการลองกู้คืนอีกครั้งก่อน';

  @override
  String get previousMonth => 'เดือนก่อนหน้า';

  @override
  String get nextMonth => 'เดือนถัดไป';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes นาที';
  }

  @override
  String get reminderInProgress => 'กำลังดำเนินอยู่';

  @override
  String get deleteCourseTitle => 'ลบวิชา';

  @override
  String get deleteCourseMessage => 'ลบวิชานี้หรือไม่?';

  @override
  String get showLunarCalendar => 'แสดงปฏิทินจันทรคติ';

  @override
  String monthDayEvents(int day, int count) {
    return 'วันที่ $day, $count กิจกรรม';
  }

  @override
  String get defaultView => 'มุมมองเริ่มต้น';

  @override
  String get generalDefaultViewSection => 'เมื่อเปิดแอป';

  @override
  String get generalViewSwitchBehavior => 'ปุ่มสลับมุมมอง';

  @override
  String get hideHomeWorkspaceNavigation => 'ซ่อนการนำทางพื้นที่ทำงาน';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'ซ่อนการนำทางพื้นที่ทำงาน แต่ยังสลับได้จากเมนูพื้นที่ทำงานบนหน้าหลัก';

  @override
  String get generalDateLabelFormat => 'รูปแบบวันที่ที่แสดง';

  @override
  String get generalDateLabelFormatLocalized => 'ตามภาษา (ก.ค. 2026)';

  @override
  String get generalDateLabelFormatSlash => 'เครื่องหมายทับ (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'การจัดวางแถบเครื่องมือ';

  @override
  String get toolbarNavigationSection => 'การนำทางในแถบเครื่องมือ';

  @override
  String get toolbarNavigationHiddenBehavior => 'การจัดการรายการที่ซ่อน';

  @override
  String get toolbarNavigationRemove => 'ซ่อนทั้งหมด';

  @override
  String get toolbarNavigationMore => 'ย้ายไปที่เพิ่มเติม';

  @override
  String get toolbarNavigationReorder => 'จัดลำดับรายการแถบเครื่องมือ';

  @override
  String get toolbarNavigationVisibility => 'แสดงรายการในแถบเครื่องมือ';

  @override
  String get toolbarNavigationTimetable => 'ตัวเลือกตารางเรียน';

  @override
  String get toolbarNavigationWeek => 'ตัวเลือกสัปดาห์';

  @override
  String get toolbarNavigationView => 'ตัวสลับมุมมอง';

  @override
  String get toolbarNavigationCategory => 'ตัวเลือกหมวดหมู่';

  @override
  String get toolbarNavigationDate => 'ตัวเลือกวันที่';

  @override
  String get generalToolbarWidthPolicy => 'การจัดสรรพื้นที่แถบเครื่องมือ';

  @override
  String get generalToolbarWidthContent => 'จัดสรรอัตโนมัติ';

  @override
  String get generalToolbarWidthBalanced => 'สมดุล';

  @override
  String get generalToolbarWidthCalendarPriority => 'ให้ความสำคัญกับหมวดหมู่';

  @override
  String get generalToolbarWidthDatePriority => 'ให้ความสำคัญกับวันที่';

  @override
  String get generalViewSwitchCycle => 'วนสลับมุมมองตามลำดับ';

  @override
  String get generalViewSwitchMenu => 'เปิดเมนูมุมมอง';

  @override
  String get generalViewSwitchTooltip => 'สลับมุมมอง';

  @override
  String get generalViewSwitchMenuTooltip => 'เลือกมุมมอง';

  @override
  String get generalViewLongPressTodayHint => 'กดค้างเพื่อกลับไปวันนี้';

  @override
  String get generalScheduleDisplaySection => 'การแสดงตารางกิจกรรม';

  @override
  String get generalTimeGridSection => 'ตารางเวลา';

  @override
  String get generalPopupSection => 'การทำงานของป๊อปอัป';

  @override
  String get quickActionsSection => 'การดำเนินการด่วน';

  @override
  String get showAddCourseFab => 'แสดงปุ่มลอยเพิ่มวิชา';

  @override
  String get showAddCourseFabHint =>
      'แสดงหรือซ่อนปุ่มลอยเพิ่มวิชาที่มุมขวาล่างของตารางเรียน';

  @override
  String get showAddEventFab => 'แสดงปุ่มลอยเพิ่มกิจกรรม';

  @override
  String get showAddEventFabHint =>
      'แสดงหรือซ่อนปุ่มลอยเพิ่มกิจกรรมที่มุมขวาล่างของตารางกิจกรรม';

  @override
  String get enableLongPressAddCourse => 'กดค้างบนช่องว่างเพื่อเพิ่มวิชา';

  @override
  String get enableLongPressAddCourseHint =>
      'กดค้างบนพื้นที่ว่างในตารางเรียนเพื่อเพิ่มวิชา';

  @override
  String get enableLongPressAddEvent => 'กดค้างบนช่องว่างเพื่อเพิ่มกิจกรรม';

  @override
  String get enableLongPressAddEventHint =>
      'ในมุมมองรายวันหรือรายสัปดาห์ กดค้างบนพื้นที่ว่างในตารางเวลาเพื่อเพิ่มกิจกรรม';

  @override
  String get developerModeTitle => 'โหมดนักพัฒนา';

  @override
  String get developerModeDescription =>
      'เครื่องมือสำหรับเพิ่มข้อมูลตัวอย่างแบบครบชุดเพื่อตรวจสอบหน้าตาและการโต้ตอบ';

  @override
  String get developerSampleLanguage => 'ภาษาของข้อมูลตัวอย่าง';

  @override
  String get developerSampleChinese => 'ภาษาจีน';

  @override
  String get developerSampleEnglish => 'ภาษาอังกฤษ';

  @override
  String get developerSampleDataDescription =>
      'เพิ่มตารางเรียนหนึ่งรายการพร้อมชุดหมวดหมู่และกิจกรรมโดยไม่แทนที่ข้อมูลเดิม';

  @override
  String get developerAddSampleData => 'เพิ่มข้อมูลตัวอย่าง';

  @override
  String get developerSampleDataAdded =>
      'เพิ่มตารางเรียนและข้อมูลกิจกรรมตัวอย่างแล้ว';

  @override
  String get developerModeLongPressHint =>
      'กดค้าง 3 วินาทีเพื่อเปิดโหมดนักพัฒนา';

  @override
  String get developerNotificationDiagnostics => 'การวินิจฉัยการแจ้งเตือน';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'ตรวจสอบสถานะการส่งบน Android สร้างแผนการเตือนเดิมใหม่ และส่งการแจ้งเตือนทดสอบอย่างปลอดภัยผ่านบริการแจ้งเตือนปกติของ Sked';

  @override
  String get developerNotificationUnsupported =>
      'การวินิจฉัยการแจ้งเตือนใช้ได้บน Android เท่านั้น';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'การวินิจฉัยการแจ้งเตือนจะพร้อมใช้เมื่อระบบประสานตารางกิจกรรมเริ่มทำงาน';

  @override
  String get developerNotificationRefresh => 'รีเฟรชการวินิจฉัย';

  @override
  String get developerNotificationSystemStatus => 'สิทธิ์การแจ้งเตือนของระบบ';

  @override
  String get developerNotificationPermissionAllowed => 'อนุญาตแล้ว';

  @override
  String get developerNotificationPermissionBlocked => 'ถูกบล็อก';

  @override
  String get developerNotificationExactAlarm => 'การปลุกตรงเวลา';

  @override
  String get developerNotificationExactAlarmAllowed => 'อนุญาตแล้ว';

  @override
  String get developerNotificationExactAlarmBlocked => 'ไม่ได้รับอนุญาต';

  @override
  String get developerNotificationPlan => 'แผนแจ้งเตือนตารางกิจกรรม';

  @override
  String get developerNotificationCoverage => 'ความครอบคลุมของการเตือน';

  @override
  String get developerNotificationCoverageReady =>
      'ตั้งเวลาการเตือนที่ทราบและมีจุดสิ้นสุดทั้งหมดโดยตรงแล้ว';

  @override
  String get developerNotificationCoverageRenewable =>
      'การเตือนที่เกิดซ้ำจะต่ออายุระยะยาวเท่าที่ระบบทำได้';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'จำนวนการปลุกที่ตั้งได้โดยตรงเต็มแล้ว การเตือนภายหลังจะต่ออายุเท่าที่ระบบทำได้';

  @override
  String get developerNotificationCoverageBlocked =>
      'ยังไม่ครบเงื่อนไขสำหรับการส่งตรงเวลา';

  @override
  String get developerNotificationCoverageFailed =>
      'การซิงค์การเตือนครั้งล่าสุดล้มเหลว';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return 'ตั้งการปลุกโดยตรง $scheduled รายการ / ความจุ $capacity รายการ';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'ข้อผิดพลาดล่าสุด: $message';
  }

  @override
  String get developerNotificationTestChannel => 'ช่องทางทดสอบ';

  @override
  String get developerNotificationTestCourse => 'การเตือนวิชาเรียน';

  @override
  String get developerNotificationTestSchedule => 'การเตือนกิจกรรม';

  @override
  String get developerNotificationImmediateTest => 'ส่งการทดสอบทันที';

  @override
  String get developerNotificationThirtySecondTest =>
      'ตั้งการทดสอบเบื้องหลังใน 30 วินาที';

  @override
  String get developerNotificationImmediateQueued =>
      'ส่งการแจ้งเตือนทดสอบทันทีแล้ว';

  @override
  String get developerNotificationThirtySecondQueued =>
      'ตั้งการทดสอบเบื้องหลังในอีก 30 วินาทีแล้ว';

  @override
  String get developerNotificationAppSwitch => 'สวิตช์การเตือนของแอป';

  @override
  String get developerNotificationAppSwitchEnabled => 'เปิดการเตือนปกติแล้ว';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'ปิดการเตือนปกติแล้ว แต่ยังทดสอบสำหรับนักพัฒนาได้';

  @override
  String get developerNotificationTimeZone => 'เขตเวลาท้องถิ่น';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'ยังไม่ได้สร้าง การทดสอบสำหรับนักพัฒนาจะสร้างช่องทางนี้';

  @override
  String get developerNotificationChannelEnabledState => 'เปิดใช้งาน';

  @override
  String get developerNotificationChannelBlockedState => 'ถูกบล็อก';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'ความสำคัญ: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'ไม่ทราบระดับความสำคัญ';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return 'รอดำเนินการ $pending รายการ / แสดงอยู่ $active รายการ';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'ระบบแสดงล่าสุดเมื่อ $time';
  }

  @override
  String get developerNotificationNoDiagnostic => 'ยังไม่มีบันทึกการคำนวณใหม่';

  @override
  String get developerNotificationNextReminder => 'การเตือนจริงครั้งถัดไป';

  @override
  String get developerNotificationNoPendingReminder =>
      'แผนปัจจุบันไม่มีการเตือนในอนาคต';

  @override
  String get developerNotificationNextRenewal =>
      'การต่ออายุเท่าที่ระบบทำได้ครั้งถัดไป';

  @override
  String get developerNotificationLastSynchronization =>
      'การซิงค์การเตือนล่าสุด';

  @override
  String get developerNotificationLateRecovery => 'การกู้คืนการเตือนที่ล่าช้า';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return 'กู้คืนการเตือน $count รายการหลังเวลาที่กำหนดไว้เดิม';
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
  String get developerNotificationReconcileOriginForeground => 'เบื้องหน้า';

  @override
  String get developerNotificationReconcileOriginBackground => 'เบื้องหลัง';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'คำนวณใหม่ทั้งหมด';

  @override
  String get developerNotificationReconcileModeRecovery => 'กู้คืน';

  @override
  String get developerNotificationRunRecovery => 'ดำเนินการกู้คืนการเตือน';

  @override
  String get developerNotificationRecoveryComplete => 'กู้คืนการเตือนเสร็จแล้ว';

  @override
  String get developerNotificationReconcileResultSuccess => 'สำเร็จ';

  @override
  String get developerNotificationReconcileResultSkipped => 'ข้ามแล้ว';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'ระงับไว้จนกว่าจะครบเงื่อนไขการส่งตรงเวลาทั้งหมด';

  @override
  String get developerNotificationReconcileResultFailed => 'ล้มเหลว';

  @override
  String get developerNotificationBackgroundLimits =>
      'ข้อจำกัดเบื้องหลังของผู้ผลิต';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'ข้อจำกัดการทำงานเบื้องหลังของผู้ผลิตอาจส่งผลต่อการส่ง';

  @override
  String get developerNotificationAutostart => 'การเริ่มเบื้องหลังของผู้ผลิต';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'ผู้ผลิต $vendor มีทางเข้าการตั้งค่าของผู้ผลิต แต่ Android ไม่สามารถแสดงสถานะการอนุญาตได้';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'ผู้ผลิต $vendor จะใช้หน้าข้อมูลแอปแทน แต่ Android ไม่สามารถแสดงสถานะการอนุญาตได้';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'ไม่มีทางเข้าการตั้งค่าเบื้องหลังของผู้ผลิตที่ใช้งานได้';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'ปลายทางที่เปิดล่าสุด: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'การตั้งค่าของผู้ผลิต';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'ข้อมูลแอป';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'ไม่มี';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'เงื่อนไขการกู้คืนหลังรีสตาร์ท';

  @override
  String get developerNotificationRebootBoundary =>
      'การกู้คืนจะเริ่มหลังปลดล็อกครั้งแรก แอปที่ถูกบังคับหยุดจะเริ่มทำงานเองไม่ได้';

  @override
  String get developerNotificationTestChecking =>
      'ยังทดสอบไม่ได้ระหว่างตรวจสอบสถานะการแจ้งเตือน';

  @override
  String get developerNotificationTestBlockedSystem =>
      'ทดสอบไม่ได้เนื่องจากการแจ้งเตือนของระบบถูกบล็อก';

  @override
  String get developerNotificationTestBlockedChannel =>
      'ทดสอบไม่ได้เนื่องจากช่องทางการแจ้งเตือนที่เลือกถูกบล็อก';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'จัดการโดยการตั้งค่าการแจ้งเตือนของ Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'ไม่ใช้กับ Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'ข้อมูลระบุแพ็กเกจ Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'พบข้อมูลระบุ MSIX แล้ว สามารถยกเลิกการแจ้งเตือนที่แสดงอยู่ได้';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'ติดตั้งรุ่น MSIX เพื่อยกเลิกการแจ้งเตือนที่แสดงอยู่ได้อย่างเชื่อถือได้';

  @override
  String get collapseWorkspaceNavigation => 'ยุบการนำทางพื้นที่ทำงาน';

  @override
  String get expandWorkspaceNavigation => 'ขยายการนำทางพื้นที่ทำงาน';

  @override
  String get schoolWebImportExitBrowser => 'ออกจากเบราว์เซอร์ในแอป';

  @override
  String get schoolWebImportEditAddress => 'แก้ไขที่อยู่';

  @override
  String get schoolWebImportAddressLabel => 'ที่อยู่เว็บ';

  @override
  String get schoolWebImportOpenAddress => 'เปิด';

  @override
  String get schoolWebImportAddressInvalid =>
      'ป้อนที่อยู่ HTTP หรือ HTTPS ที่มีโฮสต์';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'หน้าเว็บนี้ขอเปิดหน้าต่างใหม่ที่ไม่สามารถเปิดบนอุปกรณ์นี้ได้';

  @override
  String get schoolWebImportSecureConnection => 'การเชื่อมต่อที่ปลอดภัย';

  @override
  String get schoolWebImportInsecureConnection => 'การเชื่อมต่อที่ไม่ปลอดภัย';

  @override
  String get notificationSettingsSection => 'การเตือนและการแจ้งเตือน';

  @override
  String get notificationCoverage => 'ความครอบคลุมของการเตือน';

  @override
  String get notificationCoverageBlocked =>
      'Reminders are blocked and will not fire. Check notification settings.';

  @override
  String get notificationCoverageFailed =>
      'Reminders could not be synced. Open notification settings and try again.';

  @override
  String get notificationCoverageRenewable =>
      'กิจกรรมที่เกิดซ้ำโดยไม่มีวันที่สิ้นสุดจะใช้การต่ออายุเบื้องหลังเพื่อให้ครอบคลุมระยะยาว';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android ตั้งการเตือนโดยตรงได้สูงสุด $capacity รายการ ระบบจะพยายามต่ออายุการเตือนภายหลังไว้ล่วงหน้า';
  }

  @override
  String get notificationSettingsEnabled => 'เปิดการเตือนและการแจ้งเตือน';

  @override
  String get notificationSettingsEnabledHint =>
      'ตั้งเวลาเฉพาะรายการที่มีการเตือน สำหรับวิชาที่ใช้ค่าเริ่มต้น ให้กำหนดการเตือนเริ่มต้นของวิชาด้านล่าง';

  @override
  String get notificationPrecisionLimitations =>
      'การแจ้งเตือนขึ้นอยู่กับสิทธิ์ของระบบและการทำงานเบื้องหลัง การปิดเครื่อง การเปลี่ยนเวลา หรือข้อจำกัดของระบบอาจทำให้ล่าช้า';

  @override
  String get notificationSettingsEnabledSummary => 'เปิดใช้งาน';

  @override
  String get notificationSettingsDisabledSummary => 'ปิดใช้งาน';

  @override
  String get notificationDefaultsSection => 'การเตือนเริ่มต้น';

  @override
  String get notificationCourseDefaultReminder => 'การเตือนเริ่มต้นของวิชา';

  @override
  String get notificationGeneralDefaultReminder => 'การเตือนเริ่มต้นของกิจกรรม';

  @override
  String get notificationReminderOff => 'ไม่เตือน';

  @override
  String notificationReminderCustom(int minutes) {
    return 'ก่อน $minutes นาที';
  }

  @override
  String get notificationPermission => 'สิทธิ์การแจ้งเตือน';

  @override
  String get notificationPermissionGranted => 'ระบบอนุญาตแล้ว';

  @override
  String get notificationPermissionDenied => 'ระบบบล็อกไว้';

  @override
  String get notificationPermissionChecking => 'กำลังตรวจสอบสิทธิ์…';

  @override
  String get notificationPermissionRequest => 'ขอสิทธิ์';

  @override
  String get notificationPermissionOpenSettings => 'เปิดการตั้งค่าระบบ';

  @override
  String get notificationPermissionRequestFailed =>
      'อ่านสิทธิ์การแจ้งเตือนไม่ได้ โปรดลองอีกครั้ง';

  @override
  String get notificationExactAlarm => 'สิทธิ์การปลุกตรงเวลา';

  @override
  String get notificationExactAlarmAllowed => 'ระบบอนุญาตแล้ว';

  @override
  String get notificationExactAlarmRequired => 'จำเป็นสำหรับการเตือนที่ตรงเวลา';

  @override
  String get notificationExactAlarmRequest => 'อนุญาตการปลุกตรงเวลา';

  @override
  String get notificationBatteryOptimization => 'การเพิ่มประสิทธิภาพแบตเตอรี่';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'อยู่ในรายการยกเว้นการเพิ่มประสิทธิภาพแบตเตอรี่ของ Android แล้ว';

  @override
  String get notificationBatteryOptimizationWarning =>
      'Battery optimization or vendor background restrictions may delay reminders. You can adjust these in system settings.';

  @override
  String get notificationBatteryOptimizationRequest =>
      'เปิดการตั้งค่าการเพิ่มประสิทธิภาพแบตเตอรี่';

  @override
  String get notificationAutostart => 'การเริ่มเบื้องหลังของผู้ผลิต';

  @override
  String get notificationAutostartVendorHint =>
      'โปรดอนุญาตการเริ่มอัตโนมัติหรือการทำงานเบื้องหลัง เพื่อให้กู้คืนการเตือนได้หลังรีสตาร์ท';

  @override
  String get notificationAutostartFallbackHint =>
      'เปิดหน้าข้อมูลแอป Sked และอนุญาตการทำงานเบื้องหลัง Android ไม่สามารถตรวจสอบการตั้งค่าของผู้ผลิตนี้ได้';

  @override
  String get notificationAutostartUnavailable =>
      'ไม่พบหน้าการตั้งค่าของผู้ผลิต โปรดตรวจสอบหน้าข้อมูลแอป Sked ด้วยตนเอง';

  @override
  String get notificationAutostartRequest =>
      'เปิดการตั้งค่าเบื้องหลังของผู้ผลิต';

  @override
  String get notificationAutostartOpenFailed =>
      'เปิดการตั้งค่าเบื้องหลังของผู้ผลิตไม่ได้ โปรดตรวจสอบหน้าข้อมูลแอป Sked ด้วยตนเอง';

  @override
  String get notificationLockScreenTitles => 'แสดงชื่อในการแจ้งเตือน';

  @override
  String get notificationLockScreenTitlesHint =>
      'ใช้กับหน้าจอล็อกด้วย เมื่อปิด การแจ้งเตือนจะมีเฉพาะประเภทและเวลา';

  @override
  String get notificationPlatformUnsupported =>
      'แพลตฟอร์มนี้ไม่มีการแจ้งเตือนของระบบ';

  @override
  String get workspaceFeatures => 'จัดการฟีเจอร์';

  @override
  String get workspaceBoth => 'ตารางเรียนและกำหนดการ';

  @override
  String get workspaceOnlyStudent => 'ตารางเรียนเท่านั้น';

  @override
  String get workspaceOnlyGeneral => 'กำหนดการเท่านั้น';

  @override
  String get workspaceDisableTitle => 'ปิดพื้นที่ทำงานนี้หรือไม่?';

  @override
  String get workspaceDisableMessage =>
      'ข้อมูลและการตั้งค่าจะยังคงอยู่ ฟีเจอร์และการเตือนที่เกี่ยวข้องจะหยุดจนกว่าคุณจะเปิดใช้งานอีกครั้งที่นี่';

  @override
  String get workspaceEnableHint =>
      'เลือกฟีเจอร์ที่คุณใช้ ต้องเปิดใช้งานอย่างน้อยหนึ่งฟีเจอร์';

  @override
  String get workspaceLastRequired =>
      'ต้องเปิดใช้งานพื้นที่ทำงานอย่างน้อยหนึ่งพื้นที่';

  @override
  String get workspaceReminderCleanupFailed =>
      'ปิดพื้นที่ทำงานแล้ว แต่ยังล้างการเตือนไม่สำเร็จ โปรดลองกู้คืนการแจ้งเตือนอีกครั้ง';

  @override
  String get settingsDataPrivacy => 'ข้อมูลและความเป็นส่วนตัว';

  @override
  String get selectedDayAgenda => 'วันที่เลือก';

  @override
  String get notificationTroubleshooting => 'สิทธิ์และการแก้ไขปัญหา';

  @override
  String get settingsConnection => 'การเชื่อมต่อ';

  @override
  String get settingsAdvanced => 'ขั้นสูง';

  @override
  String get unsavedChangesMessage =>
      'คุณมีการเปลี่ยนแปลงที่ยังไม่ได้บันทึก ต้องการละทิ้งและออกหรือไม่?';

  @override
  String get backupWorkspaceSelection =>
      'ข้อมูลสำรองทั้งหมดมีข้อมูลและการเลือกพื้นที่ทำงานที่เปิดใช้งาน';

  @override
  String get assistantLayoutPreview => 'AI · ตัวอย่างการจัดวาง';

  @override
  String get assistantSelectionContext => 'ใช้รายการที่เลือกอยู่เป็นบริบท';

  @override
  String get assistantPreviewDescription =>
      'Discuss and work in the current workspace. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'ข้อความร่าง';

  @override
  String get assistantPreviewNoSend =>
      'เป็นเพียงตัวอย่างการจัดวาง จะไม่ส่งข้อความหรือเปลี่ยนแปลงข้อมูลใด ๆ';

  @override
  String get resizePanel => 'ปรับขนาดแผง';

  @override
  String get minimizeWindow => 'ย่อหน้าต่าง';

  @override
  String get maximizeWindow => 'ขยายหน้าต่างเต็มจอ';

  @override
  String get restoreWindow => 'คืนขนาดหน้าต่าง';

  @override
  String get closeWindow => 'ปิดหน้าต่าง';

  @override
  String get courseSystemReminder => 'การเตือนของระบบ';

  @override
  String courseReminderInherit(String reminder) {
    return 'ใช้ค่าเริ่มต้น ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'การเตือนของระบบถูกปิดในการตั้งค่าการแจ้งเตือน คุณยังบันทึกการตั้งค่าการเตือนของวิชานี้ได้';

  @override
  String get courseReminderDefaultOff =>
      'ยังไม่ได้ตั้งการเตือนเริ่มต้นของวิชา เลือกการเตือนที่กำหนดเองที่นี่ หรือตั้งค่าเริ่มต้นในการตั้งค่าการแจ้งเตือน';

  @override
  String get courseReminderDeliveryHint =>
      'การตั้งค่านี้จะบันทึกพร้อมวิชา การส่งขึ้นอยู่กับสิทธิ์การแจ้งเตือนของระบบและข้อจำกัดเบื้องหลัง';

  @override
  String get courseReminderPermissionUnknown =>
      'ยังไม่ได้ตรวจสอบสถานะการแจ้งเตือนของระบบ โปรดตรวจสอบการตั้งค่าการแจ้งเตือนก่อนพึ่งพาการเตือน';

  @override
  String get courseReminderMinutesLabel => 'จำนวนนาทีเตือนก่อนเรียน';

  @override
  String get exportAction => 'ส่งออก';

  @override
  String get datePickerSelectWeek => 'เลือกสัปดาห์';

  @override
  String get datePickerSelectMonth => 'เลือกเดือน';

  @override
  String get generalDateLabelFormatDescription =>
      'ใช้กับการนำทางวันที่บนเดสก์ท็อปและหน้าจอขนาดเล็ก';

  @override
  String get dateRangeTitle => 'เลือกช่วงวันที่';

  @override
  String get dateRangeCustom => 'กำหนดเอง';

  @override
  String get dateRangeChooseStart => 'เลือกวันที่เริ่มต้น';

  @override
  String get dateRangeChooseEnd => 'เลือกวันที่สิ้นสุด';

  @override
  String get dateRangeLimit => 'เลือก 1–14 วัน โดยรวมวันเริ่มต้นและวันสิ้นสุด';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days วัน',
      one: '1 วัน',
    );
    return 'กำหนดเอง · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'เลือกด้วยวงล้อเลื่อน';

  @override
  String get courseReminderUseDefault => 'ใช้ค่าเริ่มต้น';

  @override
  String get courseReminderInvalidMinutes =>
      'กรุณาระบุจำนวนนาทีเป็นจำนวนเต็มตั้งแต่ศูนย์ขึ้นไป';

  @override
  String get generalCustomColumnWidth => 'ความกว้างคอลัมน์ในมุมมองกำหนดเอง';

  @override
  String get generalCustomColumnWidthAuto => 'อัตโนมัติ';

  @override
  String get generalCustomColumnWidthManual => 'ความกว้างขั้นต่ำ';

  @override
  String get generalCustomColumnWidthMinimum => 'ความกว้างขั้นต่ำต่อวัน';

  @override
  String get generalCustomColumnWidthHint =>
      'ทุกวันใช้ความกว้างขั้นต่ำเท่ากัน คอลัมน์จะขยายเต็มพื้นที่ที่มีหรือเลื่อนในแนวนอน มีผลเฉพาะมุมมองกำหนดเอง';

  @override
  String get settingsAppearanceLanguage => 'รูปลักษณ์และภาษา';

  @override
  String get settingsAppearanceDetails => 'สีและเส้นขอบ';

  @override
  String get monthNoEvents => 'ไม่มีกิจกรรมในวันนี้';

  @override
  String get settingsOverview => 'ภาพรวม';

  @override
  String get settingsThemeTarget => 'ธีมสำหรับ';

  @override
  String get settingsColorMode => 'โหมดสี';

  @override
  String get settingsNotificationPreferences => 'การตั้งค่าการเตือน';

  @override
  String get settingsNotificationPreferencesSummary =>
      'การเตือนเริ่มต้น สิทธิ์ และความเชื่อถือได้';

  @override
  String get settingsFeaturesSummary => 'พื้นที่ทำงานและการนำทาง';

  @override
  String get settingsPrivacySummary =>
      'นโยบายความเป็นส่วนตัวและการล้างข้อมูลในเครื่อง';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count คาบ',
      one: '1 คาบ',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'คาบ';

  @override
  String get periodTimesDurationColumn => 'ระยะเวลา';

  @override
  String get periodTimesGapColumn => 'ช่วงพัก';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes นาที';
  }

  @override
  String get periodTimesSavePending => 'กำลังรอบันทึก…';

  @override
  String get periodTimesSaveFailed => 'ยังไม่บันทึก · บันทึกล้มเหลว';

  @override
  String get periodTimesInvalidStatus =>
      'ยังไม่บันทึก · โปรดแก้ไขเวลาที่ทำเครื่องหมายไว้';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked ไม่สามารถยืนยันได้ว่าการบันทึกครั้งล่าสุดถูกย้อนกลับแล้วหรือไม่ จึงหยุดการเขียนและเก็บสำเนาสำหรับกู้คืนไว้ โปรดตรวจสอบพื้นที่จัดเก็บแล้วลองโหลดข้อมูลอีกครั้ง';

  @override
  String get settingsPanelDisplayMode => 'รูปแบบการแสดงแผง';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'ใช้ร่วมกันในตารางเรียนและกำหนดการ';

  @override
  String get settingsPanelDisplayOverlay => 'ซ้อนทับ';

  @override
  String get settingsPanelDisplaySideBySide => 'เคียงข้างกัน';

  @override
  String get settingsPanelDisplayAutomatic => 'อัตโนมัติ';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'ซ้อนทับด้านขวาโดยไม่เปลี่ยนขนาดปฏิทิน';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'แสดงเคียงข้างกันเป็นหลัก และซ้อนทับเมื่อปฏิทินแคบเกินไปเท่านั้น';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'แสดงเคียงข้างกันเมื่อปฏิทินยังกว้างพอให้อ่านได้ มิฉะนั้นจะซ้อนทับ';

  @override
  String get toolbarNavigationEssentialHint =>
      'การปิดแสดงการตั้งค่าหรือพื้นที่ทำงานในแถบเครื่องมือจะย้ายรายการนั้นไปยังเพิ่มเติม โดยยังเข้าถึงได้ ไม่สามารถซ่อนเพิ่มเติมขณะที่มีคำสั่งจำเป็นอยู่ การสลับพื้นที่ทำงานจะแสดงเฉพาะเมื่อซ่อนแถบนำทางด้านล่างและเปิดใช้งานหลายพื้นที่ทำงาน';

  @override
  String get reminderEnded => 'สิ้นสุดแล้ว';

  @override
  String get reminderAutoCloseHint =>
      'ปิดหลัง 10 วินาที ใช้งานแผงเพื่อให้เปิดค้างไว้';

  @override
  String get showReminderIndependently => 'เปิดแยก';

  @override
  String get categoryManagerTitle => 'จัดการหมวดหมู่';

  @override
  String get categoryHidden => 'ซ่อนอยู่';

  @override
  String get categoryShowOnCalendar => 'แสดงในปฏิทิน';

  @override
  String get categoryHideOnCalendar => 'ซ่อนจากปฏิทิน';

  @override
  String get categoryEditColor => 'เปลี่ยนสีหมวดหมู่';

  @override
  String get categoryThemePalette => 'ชุดสีธีม';

  @override
  String get categoryCustomColor => 'กำหนดเอง';

  @override
  String get colorHexInvalid => 'กรุณาระบุรหัสสีเลขฐานสิบหก 6 หลัก';

  @override
  String get colorPickerHue => 'เฉดสี';

  @override
  String get colorPickerSaturation => 'ความอิ่มตัว';

  @override
  String get colorPickerValue => 'ความสว่าง';

  @override
  String get colorPickerHex => 'รหัสสีฐานสิบหก';

  @override
  String get colorPickerSpectrum => 'สเปกตรัมสี';

  @override
  String get colorPickerSpectrumKeyboardHint =>
      'ใช้ลูกศรซ้ายและขวาเพื่อปรับความอิ่มตัว และลูกศรขึ้นและลงเพื่อปรับความสว่าง';

  @override
  String categoryColorSlot(int number) {
    return 'สีธีม $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'การอัปเดตในร้านค้าอาจมาช้ากว่า โปรดตรวจสอบความพร้อมใช้งานจากหน้าร้านค้า';

  @override
  String get storePrereleaseNotice =>
      'การรับแจ้งอัปเดตเวอร์ชันทดสอบไม่ได้ทำให้คุณเข้าร่วมช่องทางทดสอบของร้านค้าโดยอัตโนมัติ';

  @override
  String get updateFoundTitle => 'มีเวอร์ชันใหม่';

  @override
  String get updateNoNotes => 'ไม่มีบันทึกประจำรุ่น';

  @override
  String get updateLater => 'ภายหลัง';

  @override
  String get updateRetry => 'ลองอีกครั้ง';

  @override
  String get updatePrerelease => 'เวอร์ชันก่อนเผยแพร่จริง';

  @override
  String get updateNetworkFailure =>
      'ไม่สามารถตรวจสอบการอัปเดตได้ โปรดตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง';

  @override
  String updateNoNewerVersion(String version) {
    return 'ไม่พบเวอร์ชันใหม่กว่า (ปัจจุบัน: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'กำลังกู้คืนข้อมูลสำรอง…';

  @override
  String get backupRestoreInProgressMessage =>
      'คุณจะเปลี่ยนข้อมูลและการตั้งค่าได้เมื่อการกู้คืนเสร็จสิ้น แต่ยังดูเนื้อหาได้ตามปกติ';

  @override
  String get managePeriodTimeSets => 'จัดการชุดเวลาคาบเรียน';

  @override
  String periodTimeSetUsageSummary(int periodCount, int timetableCount) {
    return 'จำนวนคาบ: $periodCount · ตารางเรียนที่ใช้: $timetableCount';
  }

  @override
  String chooseTimetableImportMethod(String name) {
    return 'นำเข้าเป็นตารางเรียนใหม่ หรือแทนที่ข้อมูลตารางเรียนและรายวิชาทั้งหมดใน “$name”';
  }

  @override
  String get selectAtLeastOneWeek => 'เลือกอย่างน้อยหนึ่งสัปดาห์';

  @override
  String get notificationRemindHiddenGeneralCalendars =>
      'คงการแจ้งเตือนสำหรับหมวดหมู่ที่ซ่อนอยู่';

  @override
  String get notificationRemindHiddenGeneralCalendarsHint =>
      'ใช้กับการเตือนในแอปและการแจ้งเตือนของระบบ โดยการแจ้งเตือนของระบบยังต้องเปิดใช้งานในการตั้งค่า';

  @override
  String get generalReminderFollowDefault => 'ใช้ค่าเริ่มต้น';

  @override
  String get generalReminderCustom => 'กำหนดการเตือนเอง';

  @override
  String get eventEditScopeTitle => 'แก้ไขกิจกรรมที่เกิดซ้ำ';

  @override
  String get eventEditThisOccurrence => 'เฉพาะครั้งนี้';

  @override
  String get eventEditThisAndFollowing => 'ครั้งนี้และครั้งถัดไปทั้งหมด';

  @override
  String get eventEditEntireSeries => 'ทั้งชุด';

  @override
  String get eventEditEntireSeriesHint =>
      'การเปลี่ยนแปลงจะมีผลกับกิจกรรมทั้งชุด รวมถึงครั้งที่ผ่านมา';

  @override
  String get eventEditConflict =>
      'กิจกรรมนี้มีการเปลี่ยนแปลงแล้ว ฉบับร่างของคุณยังคงอยู่ โปรดเปิดกิจกรรมอีกครั้งเพื่อตรวจสอบข้อมูลล่าสุด';

  @override
  String eventSavedToHiddenCalendar(String name) {
    return 'บันทึกไว้ในหมวดหมู่ที่ซ่อนอยู่ “$name” แล้ว';
  }

  @override
  String get viewEvent => 'ดูกิจกรรม';

  @override
  String get schoolSitesNameRequired => 'กรุณากรอกชื่อโรงเรียน';

  @override
  String get schoolSitesLoginUrlRequired => 'กรุณากรอก URL สำหรับเข้าสู่ระบบ';

  @override
  String get languageNoResults => 'ไม่พบภาษาที่ตรงกัน';

  @override
  String get themeGeneralMonthTextColors => 'ข้อความในมุมมองเดือน';

  @override
  String get themeGeneralFestivalTextColor => 'เทศกาลและวันหยุด';

  @override
  String get themeGeneralSolarTermTextColor => 'สารทสุริยคติ';

  @override
  String get themeGeneralLunarTextColor => 'วันที่ตามจันทรคติ';

  @override
  String get courseTextLowContrastHint =>
      'สีข้อความนี้อาจอ่านยากบนการ์ดวิชาบางใบ (อัตราส่วนความต่างสีต่ำกว่า 4.5:1) คุณสามารถใช้สีเดิมหรือเลือกสีอื่นได้';

  @override
  String get shortenSemesterTitle => 'ลดระยะเวลาภาคเรียนหรือไม่?';

  @override
  String shortenSemesterMessage(int weeks, int count) {
    return 'ภาคเรียนจะสิ้นสุดในสัปดาห์ที่ $weeks วิชาที่มีคาบเรียนหลังจากนั้น: $count วิชา ข้อมูลวิชาและสัปดาห์ที่เลือกจะยังคงอยู่ คืนค่าจำนวนสัปดาห์เพื่อดูอีกครั้ง';
  }

  @override
  String get defaultGeneralCalendarName => 'ปฏิทินของฉัน';

  @override
  String get icsImportReportTitle => 'รายงานการนำเข้า';

  @override
  String get icsImportReportAction => 'ดูรายงาน';

  @override
  String get icsExportFailureTitle => 'ไม่สามารถส่งออกเป็น ICS';

  @override
  String get icsCopyDiagnosticsAction => 'คัดลอกรายละเอียด';

  @override
  String get icsUnsupportedTimeZoneMessage =>
      'ICS นี้มีเขตเวลาแบบระบุชื่อที่ Sked ไม่สามารถตีความได้อย่างปลอดภัย ยังไม่มีการนำเข้าข้อมูล โปรดส่งออกเวลา UTC หรือเวลาท้องถิ่นที่ไม่ระบุเขตเวลาจากปฏิทินต้นทางแล้วลองอีกครั้ง';

  @override
  String get icsExportMonthlyAnchorMismatchMessage =>
      'ไม่สามารถแสดงกิจกรรมรายเดือนนี้ใน ICS ได้อย่างถูกต้อง โปรดส่งออก JSON เพื่อเก็บวันที่ไว้';

  @override
  String get icsExportEmptyRecurrenceMessage =>
      'กิจกรรมที่เกิดซ้ำนี้ไม่มีรายการที่ใช้ส่งออกเป็น ICS ได้ โปรดส่งออก JSON เพื่อเก็บข้อมูลไว้';

  @override
  String get icsImportedCalendarName => 'ปฏิทินที่นำเข้า';

  @override
  String get icsUntitledEventName => 'กิจกรรมไม่มีชื่อ';

  @override
  String notificationWindowsCoverageLimit(int days, int capacity) {
    return 'Windows จะตั้งเวลาเตือนเฉพาะใน $days วันข้างหน้า สูงสุดครั้งละ $capacity รายการ โปรดเปิดแอปอีกครั้งเป็นระยะเพื่ออัปเดตแผน';
  }

  @override
  String notificationWindowsCoverageSummary(int count, String date) {
    return 'การเตือนที่ตั้งเวลาไว้: $count รายการ การตรวจสอบล่าสุดครอบคลุมถึง $date';
  }

  @override
  String get notificationWindowsCoverageCapacityLimited =>
      'ถึงขีดจำกัดจำนวนการเตือนแล้ว บางรายการยังไม่ได้ตั้งเวลา โปรดเปิดแอปอีกครั้งหลังจากการเตือนที่ใกล้ถึงกำหนดทำงานแล้วเพื่ออัปเดตแผน';

  @override
  String get courseInactiveThisWeek => 'ไม่มีเรียนในสัปดาห์นี้';

  @override
  String get courseInactiveBadge => 'Off week';

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
  String get notificationSnoozeAction => 'เลื่อน 10 นาที';

  @override
  String get notificationHandledAction => 'ทำเครื่องหมายว่าจัดการแล้ว';

  @override
  String get developerTestNotificationTitle => 'การแจ้งเตือนทดสอบ Sked';

  @override
  String get developerTestNotificationCourseBody =>
      'ช่องการเตือนวิชาเรียนทำงานเป็นปกติ';

  @override
  String get developerTestNotificationScheduleBody =>
      'ช่องการเตือนกิจกรรมทำงานเป็นปกติ';

  @override
  String get eventRecurrenceExceptionsChangeTitle => 'Change repeat pattern?';

  @override
  String get eventRecurrenceExceptionsChangeMessage =>
      'Previously skipped dates stay skipped only if the new repeat pattern still has an occurrence on that date. Other skip records will be removed. Turning repeats off removes all skip records. Events edited separately stay unchanged.';

  @override
  String get noPendingReminders => 'No pending reminders.';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentNewConversation => 'New conversation';

  @override
  String get agentConversations => 'Conversations';

  @override
  String get agentRenameConversation => 'Rename conversation';

  @override
  String get agentDeleteConversation => 'Delete conversation?';

  @override
  String get agentDeleteConversationMessage =>
      'This stops its active run and deletes its messages, source material and draft. Changes already made to your schedules remain.';

  @override
  String get agentConversationActions => 'Conversation actions';

  @override
  String get agentEmptyHistory => 'No conversations yet.';

  @override
  String get agentEmptyConversation =>
      'Describe what you want to view or change in Sked.';

  @override
  String get agentMessageHint => 'Message Agent';

  @override
  String get agentSend => 'Send';

  @override
  String get agentStop => 'Stop';

  @override
  String get agentRunning => 'Working…';

  @override
  String get agentStopped => 'Stopped. Completed changes remain saved.';

  @override
  String get agentRunFailed => 'This run could not finish.';

  @override
  String get agentOperationFailed =>
      'Could not save or complete this action. Your input is kept here.';

  @override
  String get agentInitializing => 'Loading Agent…';

  @override
  String get agentInitializationFailed => 'Agent could not finish loading.';

  @override
  String get agentInitializationApplicationStorage =>
      'Application storage is not ready. Return to the workspace and resolve its storage or recovery notice before retrying.';

  @override
  String get agentInitializationConversationStorage =>
      'Saved chats could not be loaded. Existing records are preserved. Check storage access or archive format, then retry.';

  @override
  String get agentInitializationConnectionStorage =>
      'The saved connection could not be initialized. Open Agent settings to review it, then retry.';

  @override
  String get agentRetry => 'Retry';

  @override
  String get agentDisabled => 'Agent is disabled in Feature management.';

  @override
  String get agentMaintenance =>
      'Data maintenance is in progress. Wait before starting another action.';

  @override
  String get agentConfigureFirst =>
      'Configure the model connection before sending a message.';

  @override
  String get agentModePlan => 'Plan';

  @override
  String get agentModeAsk => 'Ask';

  @override
  String get agentModeFull => 'Full';

  @override
  String get agentModePlanDescription =>
      'View data and propose changes without applying them.';

  @override
  String get agentModeAskDescription =>
      'Ask for approval before applying changes.';

  @override
  String get agentModeFullDescription =>
      'Apply changes without asking each time.';

  @override
  String get agentAssistant => 'Agent';

  @override
  String get agentYou => 'You';

  @override
  String get agentNotice => 'Notice';

  @override
  String get agentToolResponse => 'Tool response';

  @override
  String get agentToolArguments => 'Tool arguments';

  @override
  String get agentSourceMaterial => 'Source material';

  @override
  String get agentSourceTruncated =>
      'This source was shortened before it was attached.';

  @override
  String get agentApprovalRequired => 'Review the proposed changes';

  @override
  String get agentPlanDetails => 'Change details';

  @override
  String get agentApprove => 'Approve these changes';

  @override
  String get agentReject => 'Reject';

  @override
  String get agentApiDataNotice =>
      'Agent sends your messages, attachments, and task-related app data returned by tools to the API service you configure.';

  @override
  String get agentModelSettings => 'Agent model settings';

  @override
  String get agentEndpoint => 'API endpoint';

  @override
  String get agentModel => 'Model';

  @override
  String get agentProtocol => 'API protocol';

  @override
  String get agentApiKey => 'API key';

  @override
  String get agentKeyHint => 'Leave blank to keep the saved key.';

  @override
  String get agentShowKey => 'Show key';

  @override
  String get agentHideKey => 'Hide key';

  @override
  String get agentClearKey => 'Remove the saved key';

  @override
  String get agentInvalidEndpoint =>
      'Enter a valid HTTP or HTTPS endpoint without credentials or a fragment.';

  @override
  String get agentRequiredField => 'Enter a value.';

  @override
  String get agentSaveFailed =>
      'Could not save the connection. Your input is kept for retry.';

  @override
  String get agentSaving => 'Saving…';

  @override
  String get schoolWebAgentReviewTitle => 'Review import content';

  @override
  String get schoolWebAgentReviewHint =>
      'Review the prepared content. Agent will use it as import source material in a new conversation.';

  @override
  String get schoolWebAgentHandoff => 'Continue with Agent';

  @override
  String get agentChangesSaved => 'Changes saved';

  @override
  String agentNotificationEffect(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'pending': 'Reminder scheduling is pending.',
      'applied': 'The reminder schedule was updated.',
      'superseded': 'A newer change replaced this reminder plan.',
      'failed': 'Reminder scheduling failed. Your changes are saved.',
      'blocked':
          'Device permissions or notification settings blocked scheduling.',
      'unsupported': 'Reminder scheduling is unavailable on this platform.',
      'notRequired': 'This change does not require rescheduling reminders.',
      'other': 'The reminder scheduling result needs checking.',
    });
    return '$_temp0';
  }

  @override
  String get agentActionApplied => 'Action completed';

  @override
  String get agentActionUncertain => 'Result needs checking';

  @override
  String get agentPlanReady => 'Changes prepared';

  @override
  String get agentActionFailed => 'Action not completed';

  @override
  String agentChangeCount(int count) {
    return '$count changes';
  }

  @override
  String get agentChangeCreated => 'Added';

  @override
  String get agentChangeDeleted => 'Deleted';

  @override
  String get agentChangeUpdated => 'Updated';

  @override
  String get agentChangeArchived => 'Archived';

  @override
  String get agentChangeRestored => 'Restored';

  @override
  String get agentLayoutWidth => 'Panel width';

  @override
  String get agentLayoutHeight => 'Panel height';

  @override
  String get agentLayoutDockedWidth => 'Side-by-side panel width';

  @override
  String get agentLayoutResources => 'Workspace resources';

  @override
  String get agentLayoutCourseDetails => 'Course details';

  @override
  String get agentLayoutEventDetails => 'Event details';

  @override
  String get agentViewObject => 'View item';

  @override
  String get agentMoreChanges =>
      'More changes are included in the saved operation record.';

  @override
  String get agentUndo => 'Undo these changes';

  @override
  String get agentValueBefore => 'Before';

  @override
  String get agentValueAfter => 'After';

  @override
  String get agentShowMoreChanges => 'Show more changes';

  @override
  String get agentConnectionChanged =>
      'The model connection has changed. Start a new conversation before sending content to the new endpoint.';

  @override
  String get agentLimitsReached =>
      'This run reached its limit. Try a smaller task or continue in another run.';

  @override
  String get agentSensitiveContent =>
      'The message contains an API key. Remove the key before sending.';

  @override
  String get agentRequestFailed =>
      'The model request failed. Check the connection and selected model, then retry.';

  @override
  String get agentQueueFollowUp => 'Queue next message';

  @override
  String get agentSteer => 'Update current request';

  @override
  String get agentContinue => 'Continue';

  @override
  String agentQueuedMessages(int count) {
    return '$count queued messages';
  }

  @override
  String get agentRunPreferences => 'Run preferences';

  @override
  String get agentSystemInstructions => 'Instructions for all conversations';

  @override
  String get agentMaxModelRounds => 'Maximum model requests per run';

  @override
  String get agentMaxToolCalls => 'Maximum tool calls per run';

  @override
  String get agentMaxTotalTokens => 'Maximum reported tokens per run';

  @override
  String get agentHistoryRetentionDays =>
      'History retention (days; 0 keeps history)';

  @override
  String get agentPreferenceLimitHint =>
      'Keep forever, or choose 7–3650 days. Only finished conversations without drafts or queued input are removed.';

  @override
  String get agentPreferencesSaved => 'Preferences saved';

  @override
  String get agentInvalidPreference =>
      'Enter a value within the displayed range.';

  @override
  String get agentBackupConnectionPreserved =>
      'The local Agent connection, permissions and credentials are preserved. This backup will not change the model connection.';

  @override
  String get agentArchiveConversation => 'Archive conversation';

  @override
  String get agentArchivedConversations => 'Archived conversations';

  @override
  String get agentRestoreConversation => 'Restore conversation';

  @override
  String get agentExportConversation => 'Export conversation';

  @override
  String agentSavedConnectionHint(String endpoint) {
    return 'Diagnostics use the saved connection: $endpoint. Unsaved edits are not sent.';
  }

  @override
  String get agentTestConnection => 'Test saved connection';

  @override
  String get agentLoadModels => 'Get models';

  @override
  String get agentConnectionOk => 'Connection succeeded';

  @override
  String get agentToolsObserved => 'Valid tool call received';

  @override
  String get agentToolsUnverified =>
      'Connected, but tool calling was not verified';

  @override
  String get agentModelsPartial => 'The service returned a partial model list.';

  @override
  String get agentChooseModel => 'Choose a model';

  @override
  String get agentRecoveryRequired =>
      'Check the previous operation result first. Only reading is currently allowed.';

  @override
  String get agentAttachFile => 'Attach a text file';

  @override
  String get agentRemoveAttachment => 'Remove attachment';

  @override
  String get agentAttachmentTooLarge =>
      'This attachment exceeds the 512 KiB limit.';

  @override
  String get agentAttachmentFailed =>
      'Could not attach the file. Your conversation is unchanged.';

  @override
  String get agentHttpTransportWarning =>
      'This connection uses HTTP. Testing, getting models or sending a request transmits the API key and request content without transport encryption.';

  @override
  String get agentHttpTransportApproval =>
      'Allow HTTP requests to this connection?';

  @override
  String get agentHttpTransportScope =>
      'This permission can be reused for the same saved connection until the app closes. It does not approve changes to your data.';

  @override
  String get agentModelSelection => 'Model';

  @override
  String get agentThinkingEffort => 'Thinking effort';

  @override
  String get agentEffortNone => 'None';

  @override
  String get agentEffortMinimal => 'Minimal';

  @override
  String get agentEffortLow => 'Low';

  @override
  String get agentEffortMedium => 'Medium';

  @override
  String get agentEffortHigh => 'High';

  @override
  String get agentEffortXhigh => 'Extra high';

  @override
  String get agentEffortMax => 'Maximum';

  @override
  String get agentModelNextRunHint =>
      'Changes apply to the next request. The current request keeps its model and thinking effort.';

  @override
  String get agentModelSelectionRequired =>
      'This request\'s model or thinking effort is no longer enabled. Choose another option, then continue.';

  @override
  String get agentEnabledModels => 'Available models';

  @override
  String get agentAddModel => 'Add model';

  @override
  String get agentModelSearch => 'Search model IDs';

  @override
  String get agentDefaultModel => 'Default model';

  @override
  String get agentDefaultEffort => 'Default thinking effort';

  @override
  String get agentAllowedEfforts => 'Available thinking efforts';

  @override
  String get agentNoModelsSelected => 'Select or add at least one model.';

  @override
  String get agentModelCapabilityHint =>
      'A model list does not describe supported thinking levels. Select the levels your service supports and choose an explicit default.';

  @override
  String get agentModelEffortsRequired =>
      'Select at least one thinking effort and choose its default for every enabled model.';

  @override
  String get agentRemoveModel => 'Remove model';

  @override
  String get agentManualModelId => 'Model ID';

  @override
  String get agentSettingsTitle => 'Agent settings';

  @override
  String get agentConnectionAndModels => 'Connection and models';

  @override
  String get agentConnectionSettings => 'Connection settings';

  @override
  String get agentSettingsChanged =>
      'Settings changed elsewhere. Reopen this page to load the latest values.';

  @override
  String get agentSettingsSaveFailed =>
      'Couldn\'t save settings. Your changes are still here.';

  @override
  String get agentSettingsSummary => 'Manage models and Agent preferences';

  @override
  String get agentOpenWorkspace => 'Open full chat';

  @override
  String get agentSearchConversations => 'Search conversations';

  @override
  String get agentHideConversations => 'Hide conversations';

  @override
  String get agentShowConversations => 'Show conversations';

  @override
  String get agentJumpToLatest => 'Latest messages';

  @override
  String get agentCopyMessage => 'Copy message';

  @override
  String get agentCopyCode => 'Copy code';

  @override
  String get agentCopied => 'Copied';

  @override
  String get agentCopyFailed => 'Could not copy. Try again.';

  @override
  String get agentChatWelcome => 'What can I help with?';

  @override
  String get agentActivityDetails => 'Activity details';

  @override
  String agentActivitySummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activities',
      one: '1 activity',
    );
    return '$_temp0';
  }

  @override
  String get agentActivityCompleted => 'Completed';

  @override
  String get agentActivityFailed => 'Failed';

  @override
  String get agentActivityUncertain => 'Needs review';

  @override
  String get agentActivityNotStarted => 'Not started';

  @override
  String get agentActivityEmptyOutput => 'No content';

  @override
  String get agentCopyActivity => 'Copy activity details';

  @override
  String get agentActivityRead => 'Read information';

  @override
  String get agentActivityCapabilities => 'Check available features';

  @override
  String get agentActivityPrepare => 'Prepare changes';

  @override
  String get agentActivityCommit => 'Save changes';

  @override
  String get agentActivityNotifications => 'Check reminders';

  @override
  String get agentActivityKnowledge => 'Work with knowledge';

  @override
  String get agentActivitySettings => 'Work with settings';

  @override
  String get agentActivitySystem => 'Use system features';

  @override
  String get agentActivityTool => 'Use a tool';

  @override
  String get agentConversationSearchEmpty => 'No matching conversations';

  @override
  String get agentPermissionMode => 'Permission mode';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentMemories => 'Memory';

  @override
  String get agentKnowledgeAdd => 'Add';

  @override
  String get agentKnowledgeBody => 'Content';

  @override
  String get agentKnowledgeBuiltin => 'Built-in';

  @override
  String get agentKnowledgeConflict =>
      'This item changed. Reopen it before saving.';

  @override
  String get agentKnowledgeCustom => 'Custom';

  @override
  String get agentKnowledgeDelete => 'Delete';

  @override
  String get agentKnowledgeDeleteConfirm =>
      'Delete this item? Recent local history may retain a copy for undo.';

  @override
  String get agentKnowledgeEdit => 'Edit';

  @override
  String get agentKnowledgeEmpty => 'Nothing saved yet';

  @override
  String get agentKnowledgeEnabled => 'Enabled';

  @override
  String get agentKnowledgeHelp =>
      'Skills guide how the Agent handles tasks. You and the Agent share them. Changes apply to future runs.';

  @override
  String get agentKnowledgeInvalid =>
      'Check the content, tool names and size limits.';

  @override
  String get agentKnowledgeMemoryHelp =>
      'Shared notes and preferences. The Agent may update them during a conversation using its current permissions. Check current data before relying on older details.';

  @override
  String get agentKnowledgeModified => 'Customized built-in';

  @override
  String get agentKnowledgeOriginalChanged =>
      'The built-in version changed. Your edits are kept until you restore the original.';

  @override
  String get agentKnowledgeReload => 'Reload';

  @override
  String get agentKnowledgeRestoreOriginal => 'Restore original';

  @override
  String get agentKnowledgeSaved => 'Saved';

  @override
  String get agentKnowledgeSearch => 'Search';

  @override
  String get agentKnowledgeSource => 'Source or context';

  @override
  String get agentKnowledgeStaleReference =>
      'Referenced data may have changed. Check current data before using this note.';

  @override
  String get agentKnowledgeStorageFailed =>
      'The saved state could not be confirmed. Reload to check it before making more changes.';

  @override
  String get agentKnowledgeSummary => 'Summary';

  @override
  String get agentKnowledgeTitle => 'Title';

  @override
  String get agentKnowledgeUnavailable => 'Unavailable';

  @override
  String get agentKnowledgeUndo => 'Undo';

  @override
  String get agentSkillAdvanced => 'Skill options';

  @override
  String get agentSkillOptionalTools => 'Optional tools, one name per line';

  @override
  String get agentSkillRequiredTools => 'Required tools, one name per line';

  @override
  String get agentSkillTriggers => 'When to use this skill, one hint per line';

  @override
  String get agentComposerActions => 'Message actions';

  @override
  String get agentMakeDefaultModel => 'Use as default model';

  @override
  String get agentModelIdExists => 'This model has already been added.';

  @override
  String get agentAttachAnyFile => 'Attach a file';

  @override
  String get agentFileLocal => 'Saved on this device';

  @override
  String get agentFileSaving => 'Saving file…';

  @override
  String get agentFilePreparing => 'Preparing to send…';

  @override
  String get agentFileSending => 'Sending file…';

  @override
  String get agentFileAccepted => 'Accepted by the service';

  @override
  String get agentFileFailed => 'File was not accepted';

  @override
  String get agentFileCancelled => 'File transfer stopped';

  @override
  String get agentFileUnknown => 'Service acceptance is unknown';

  @override
  String get agentFileTooLarge => 'A file can be up to 32 MB.';

  @override
  String get agentFileChanged =>
      'The file changed while it was being read. Select it again.';

  @override
  String get agentFileMissing =>
      'This file is no longer available on this device. Select it again to use it.';

  @override
  String get agentFileCorrupt =>
      'The saved file could not be verified. Select the original file again.';

  @override
  String get agentFileUnavailable =>
      'File storage is unavailable. Retry after restoring access.';

  @override
  String get agentFileUnsupported =>
      'This API protocol cannot send this file type. The local file is kept.';

  @override
  String get agentFileConflict =>
      'The conversation changed while the file was being added, or the attachment limit was reached.';

  @override
  String get agentFilePreview => 'Preview file';

  @override
  String get agentFileUseAgain => 'Use in the next message';

  @override
  String get agentFileNoPreview =>
      'Preview is not available for this file type. The saved file can still be sent if the API supports it.';

  @override
  String get agentFilePreviewFailed => 'This image could not be displayed.';

  @override
  String get agentFileReceivedHint =>
      'Acceptance confirms the service received the request; it does not confirm that the model read every file.';

  @override
  String get selectiveBackupAdd => 'Add';

  @override
  String get selectiveBackupAgentConnection => 'Agent connection and models';

  @override
  String get selectiveBackupAgentPreferences => 'Agent preferences';

  @override
  String get selectiveBackupApplicationSettings => 'Application settings';

  @override
  String get selectiveBackupCalendars => 'Calendar categories';

  @override
  String get selectiveBackupCalendarSettings => 'Calendar settings';

  @override
  String get selectiveBackupCancelled =>
      'Restore cancelled. Your selection is kept.';

  @override
  String get selectiveBackupClearSelection => 'Clear selection';

  @override
  String get selectiveBackupConfirmBody =>
      'Selected objects with the same ID will be replaced. New objects will be added, and unselected objects will be kept.';

  @override
  String get selectiveBackupConfirmTitle => 'Restore selected data?';

  @override
  String get selectiveBackupConflict =>
      'Some selected objects conflict with data used elsewhere. Include the related objects or cancel this restore.';

  @override
  String get selectiveBackupConversations => 'Conversations';

  @override
  String selectiveBackupCopiedDependencies(int count) {
    return 'Copy and rebind $count dependencies';
  }

  @override
  String get selectiveBackupCurrentData => 'Current data';

  @override
  String get selectiveBackupDependencies =>
      'Required dependencies are included automatically. Conflicting dependencies are copied and linked only to the selected objects.';

  @override
  String get selectiveBackupDescription =>
      'Choose individual objects and settings groups to back up or restore. Conversation files can be selected separately.';

  @override
  String get selectiveBackupExclusions =>
      'API keys, cookies, system permissions and execution approvals are excluded. Restored chats contain history only and do not resume old actions.';

  @override
  String get selectiveBackupExportSelection => 'Choose data to back up';

  @override
  String get selectiveBackupFileMissing =>
      'This backup contains a reference only; file bytes are not included.';

  @override
  String get selectiveBackupFiles => 'Conversation files';

  @override
  String get selectiveBackupFilesDescription =>
      'Select file contents separately. Unchecked files retain only history references; their contents will be unavailable after restore.';

  @override
  String selectiveBackupFileSize(int bytes) {
    return '$bytes bytes';
  }

  @override
  String get selectiveBackupInvalid => 'This file is not a valid Sked backup.';

  @override
  String get selectiveBackupLimit =>
      'This backup exceeds the supported size or object limit.';

  @override
  String get selectiveBackupMemories => 'Memory';

  @override
  String get selectiveBackupNewerVersion =>
      'This backup uses a newer format. Update Sked before restoring it.';

  @override
  String get selectiveBackupNotificationSettings => 'Notification settings';

  @override
  String get selectiveBackupOpenFile => 'Open backup';

  @override
  String get selectiveBackupPeriodTimes => 'Period time sets';

  @override
  String get selectiveBackupRecoveryPending =>
      'A restore is unfinished. Continue the same restore before changing data.';

  @override
  String get selectiveBackupReplace => 'Replace';

  @override
  String get selectiveBackupRestore => 'Restore';

  @override
  String selectiveBackupRestoreCounts(int added, int replaced) {
    return 'Add $added; replace $replaced';
  }

  @override
  String get selectiveBackupRestored => 'Selected data restored';

  @override
  String get selectiveBackupRestoreSelection => 'Choose data to restore';

  @override
  String get selectiveBackupResume => 'Continue restore';

  @override
  String get selectiveBackupReviewRestore => 'Review restore';

  @override
  String get selectiveBackupSave => 'Save backup';

  @override
  String get selectiveBackupSaved => 'Backup saved';

  @override
  String get selectiveBackupSchoolSites => 'School sites';

  @override
  String get selectiveBackupSearch => 'Search objects';

  @override
  String get selectiveBackupSelectAll => 'Select all';

  @override
  String selectiveBackupSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectiveBackupSettings => 'Settings groups';

  @override
  String get selectiveBackupSkills => 'Skills';

  @override
  String get selectiveBackupTimetables => 'Timetables';

  @override
  String get selectiveBackupTimetableSettings => 'Timetable settings';

  @override
  String get selectiveBackupTitle => 'Selective backup and restore';

  @override
  String get selectiveBackupUnavailable =>
      'Could not finish this operation. Check storage access and retry; an unfinished restore will continue from its saved progress.';

  @override
  String get selectiveBackupWorkspaceSettings => 'Workspace settings';

  @override
  String get agentEditAndRedo => 'Edit and redo';

  @override
  String get agentRegenerateReply => 'Regenerate reply';

  @override
  String get agentHistoryVersions => 'Message history';

  @override
  String get agentPreviousReply => 'Previous reply version';

  @override
  String get agentNextReply => 'Next reply version';

  @override
  String agentReplyVersion(int current, int total) {
    return '$current/$total';
  }

  @override
  String get agentRedoExplanation =>
      'This undoes Agent changes from this entire turn onward, then runs only the edited request. Manual edits and other conversations are preserved.';

  @override
  String get agentRedoPending =>
      'History redo is unfinished. Continue this operation before sending another request.';

  @override
  String get agentRedoConflict =>
      'The complete turn cannot be safely undone. Keep the current data and revise your request, or cancel.';

  @override
  String get agentKeepAndRevise => 'Keep data and revise';

  @override
  String get selectiveBackupDeviceSettings => 'Device settings';

  @override
  String get selectiveBackupDeviceLayout => 'Panel dimensions';

  @override
  String get selectiveBackupDeviceDeveloperUi =>
      'Developer preview preferences';

  @override
  String selectiveBackupDeviceGroupPlatform(String group, String platform) {
    return '$group · $platform';
  }

  @override
  String selectiveBackupDeviceUnsupported(String platform) {
    return 'Device settings from $platform do not apply to this platform. Your local settings will be kept.';
  }

  @override
  String selectiveBackupUnsupportedGroups(int count) {
    return '$count unsupported device settings groups will be skipped';
  }

  @override
  String get agentClearDataWarning =>
      'This permanently deletes timetables, events, settings, school sites, chats and their files, skills, memories, local backups and recovery copies, API keys, and the local school sign-in session, then exits Sked. Exported files in other locations are kept. This cannot be undone.';

  @override
  String get agentActivityCourses => 'Courses';

  @override
  String get agentActivityFreeSlots => 'Free slots';

  @override
  String get agentActivityConflicts => 'Conflict check';

  @override
  String get agentKnowledgeAllTypes => 'All types';

  @override
  String get agentKnowledgeAllStates => 'All states';

  @override
  String get agentKnowledgeDisabled => 'Disabled';

  @override
  String get agentKnowledgeMissingTools => 'Required tools unavailable';

  @override
  String get agentKnowledgeNoMatches => 'No matching items';

  @override
  String get schoolWebAgentImportTask =>
      'Organize and import a timetable from the reviewed content. Ask me about missing details.';

  @override
  String get schoolWebAgentSourceTitle => 'School page';

  @override
  String get agentKnowledgeFullSource => 'Full source text';

  @override
  String get agentConversationGuidanceTitle => 'Conversation guidance';

  @override
  String get agentConversationGuidanceHint =>
      'Set response preferences to use in all conversations.';

  @override
  String get agentRunLimitsTitle => 'Limits per run';

  @override
  String get agentRunLimitsHint =>
      'Limit model requests, tool calls and token usage for each run.';

  @override
  String get agentHistoryRetentionTitle => 'Chat history retention';

  @override
  String get agentApprovalReviseHint =>
      'Describe the changes in the message box, then choose “Update current request”. The pending changes have not been approved.';

  @override
  String get timetableImportContinueWithAgent => 'Continue with Agent';

  @override
  String get timetableImportTextContent => 'Timetable content';

  @override
  String get timetableImportJsonAction => 'Import JSON';

  @override
  String get agentReusePeriodTimeSet => 'Reuse existing period times';
}
