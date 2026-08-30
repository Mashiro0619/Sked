// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Bạn học';

  @override
  String weekLabel(int week) {
    return 'Tuần $week';
  }

  @override
  String get addCourse => 'Thêm khóa học';

  @override
  String get settings => 'Cài đặt';

  @override
  String get multiTimetableSwitch => 'Chuyển đổi lịch trình';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Thời gian biểu hiện tại · $weeks tuần';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Nhấn để chuyển · $weeks tuần';
  }

  @override
  String get editTimetable => 'Chỉnh sửa lịch trình';

  @override
  String get schoolImportResultEditorTitle => 'Edit parsed result';

  @override
  String get schoolImportParsePageTitle => 'Phân tích thời khóa biểu';

  @override
  String get schoolImportParsePageParsing => 'Đang phân tích…';

  @override
  String get schoolImportParsePageFailed => 'Phân tích không thành công';

  @override
  String get schoolImportParsePageComplete => 'Đã phân tích xong';

  @override
  String get schoolImportParsePageContinue => 'Tiếp tục';

  @override
  String get schoolImportParsePageRawContent => 'Phản hồi thô';

  @override
  String get schoolImportParsePageExpandRaw => 'Mở rộng phản hồi thô';

  @override
  String get schoolImportParsePageCollapseRaw => 'Thu gọn phản hồi thô';

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
  String get createTimetable => 'Thời gian mới';

  @override
  String get jumpToWeek => 'Nhảy đến tuần';

  @override
  String get timetable => 'Thời gian';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Tên lịch trình';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Tổng số tuần';

  @override
  String get delete => 'Xóa';

  @override
  String get cancel => 'Hủy bỏ';

  @override
  String get save => 'Lưu';

  @override
  String get deleteTimetableTitle => 'Xóa lịch trình';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Xóa \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Chưa có lịch trình';

  @override
  String get noTimetableMessage =>
      'Tạo một lịch trình hoặc nhập một từ một tệp JSON.';

  @override
  String get importTimetable => 'Nhập lịch trình';

  @override
  String get courseName => 'Tên khóa học';

  @override
  String get location => 'Địa điểm';

  @override
  String get dayOfWeek => 'Ngày';

  @override
  String get semesterWeeks => 'Tuần';

  @override
  String get startTime => 'Thời gian bắt đầu';

  @override
  String get endTime => 'Thời gian kết thúc';

  @override
  String get linkedPeriods => 'Các giai đoạn liên kết';

  @override
  String get linkedPeriodsUnmatched =>
      'Không có thời gian phù hợp với thời gian hiện tại. Nhấn để chọn thủ công.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Thời gian $start-$end';
  }

  @override
  String get teacherName => 'Giáo viên';

  @override
  String get credits => 'Tín dụng';

  @override
  String get remarks => 'Lưu ý';

  @override
  String get customFields => 'Các trường tùy chỉnh';

  @override
  String get customFieldsHint => 'Một cho mỗi dòng, định dạng: khóa: giá trị';

  @override
  String get more => 'Thêm';

  @override
  String get selectDayOfWeek => 'Chọn ngày';

  @override
  String get selectSemesterWeeks => 'Chọn tuần';

  @override
  String get selectAll => 'Chọn tất cả';

  @override
  String get clear => 'Xóa';

  @override
  String get confirm => 'Xác nhận';

  @override
  String get selectLinkedPeriods => 'Chọn các giai đoạn liên kết';

  @override
  String get addCourseTitle => 'Thêm khóa học';

  @override
  String get editCourseTitle => 'Chỉnh sửa khóa học';

  @override
  String get editCourseTooltip => 'Chỉnh sửa khóa học';

  @override
  String get place => 'Địa điểm';

  @override
  String get time => 'Thời gian';

  @override
  String get notFilled => 'Không điền';

  @override
  String get none => 'Không có';

  @override
  String get conflictCourses => 'Các khóa học xung đột';

  @override
  String get locationNotFilled => 'Vị trí không đầy';

  @override
  String get setAsDisplayed => 'Đặt như được hiển thị';

  @override
  String get editThisCourse => 'Chỉnh sửa khóa học này';

  @override
  String get settingsTitle => 'Cài đặt';

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
  String get noTimetableSettings => 'Hiện tại không có lịch trình cho cài đặt.';

  @override
  String get semesterStartDate => 'Ngày bắt đầu học kỳ';

  @override
  String get periodTimeSets => 'Thời gian thiết lập';

  @override
  String get noPeriodTimeAvailable => 'Không có thời gian có sẵn';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count thời gian';
  }

  @override
  String get coursePopupDismissSetting =>
      'Cho phép bên ngoài nhấn để đóng khóa học popup';

  @override
  String get coursePopupDismissSettingHint =>
      'Tắt điều này cũng vô hiệu hóa thanh thải cuộn xuống.';

  @override
  String get preserveTimetableGaps => 'Bảo tồn khoảng trống lịch trình';

  @override
  String get preserveTimetableGapsHint =>
      'Khi nghỉ, các khoảng trống ăn trưa và nghỉ ngơi bị sụp đổ vì vậy các lớp học sau đó di chuyển lên.';

  @override
  String get showPastEndedCourses => 'Hiển thị các khóa học đã kết thúc';

  @override
  String get showPastEndedCoursesHint =>
      'Hiển thị các khóa học đã kết thúc vào tuần hiện tại thực sự với phong cách màu xám nhẹ hơn.';

  @override
  String get showFutureCourses => 'Hiển thị các khóa học tương lai';

  @override
  String get showFutureCoursesHint =>
      'Hiển thị các khóa học không hoạt động trong tuần này nhưng sẽ xuất hiện trong các tuần sau với phong cách xám.';

  @override
  String get timetableDisplaySettings => 'Hiển thị lịch trình và tương tác';

  @override
  String get timetableDisplaySettingsDesc =>
      'Hiển thị môn học, bố cục, cử chỉ đổi tuần và thêm nhanh';

  @override
  String get showTimetableGridLines => 'Hiển thị các dòng lưới lịch trình';

  @override
  String get showTimetableGridLinesHint =>
      'Kiểm soát xem các đường lưới ngang và dọc có thể nhìn thấy trong lịch trình hay không.';

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
  String get liveCourseOutlineColor => 'Màu sắc phác thảo khóa học';

  @override
  String get liveCourseOutlineColorHint =>
      'Chọn liệu phác thảo có nhắm mục tiêu khóa học hiện tại / tiếp theo hoặc tất cả các khóa học được hiển thị trên trang hiện tại hay không.';

  @override
  String get liveCourseOutlineSettings => 'Khóa học phác thảo';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Cấu hình xem phác thảo có được kích hoạt hay không, nó nhắm mục tiêu gì, liệu nó theo màu chủ đề và màu phác thảo hiệu quả hay không.';

  @override
  String get liveCourseOutlineEnabled => 'Kích hoạt phác thảo';

  @override
  String get liveCourseOutlineFollowTheme => 'Theo chủ đề màu';

  @override
  String get liveCourseOutlineTarget => 'Mục tiêu phác thảo';

  @override
  String get liveCourseOutlineTargetCurrentOrNext =>
      'Khóa học hiện tại/tiếp theo';

  @override
  String get liveCourseOutlineTargetAllDisplayed =>
      'Tất cả các khóa học được hiển thị';

  @override
  String get liveCourseOutlineEffectiveColor => 'Màu sắc hiệu quả';

  @override
  String get liveCourseOutlineCustomColor => 'Màu sắc phác thảo tùy chỉnh';

  @override
  String get liveCourseOutlineWidth => 'Chiều rộng phác thảo';

  @override
  String get outlineWidthUnit => 'phim';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get languagePageDescription =>
      'Chọn một trong những ngôn ngữ thực sự có sẵn trong ứng dụng.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'Tiếng Anh';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Phản ứng API';

  @override
  String get theme => 'Chủ đề';

  @override
  String get themeFollowSystem => 'Hệ thống theo dõi';

  @override
  String get themeLight => 'Ánh sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get themeColor => 'Màu chủ đề';

  @override
  String get themeColorModeSingle => 'Màu chủ đề đơn';

  @override
  String get themeColorModeColorful => 'Đầy màu sắc';

  @override
  String get themeColorUiColors => 'Màu sắc UI';

  @override
  String get themeColorCourseColors => 'Màu sắc khóa học';

  @override
  String get themeColorPrimary => 'Sơ cấp';

  @override
  String get themeColorSecondary => 'Thứ cấp';

  @override
  String get themeColorTertiary => 'Thứ ba';

  @override
  String get themeColorCourseText => 'Văn bản khóa học';

  @override
  String get themeColorCourseTextAuto => 'Tự động';

  @override
  String get themeColorCourseTextCustom => 'Màu sắc tùy chỉnh';

  @override
  String get themeColorCourseColorsEmpty =>
      'Màu sắc khóa học sẽ được tạo ra sau khi nhập một lịch trình.';

  @override
  String get themeCustomColor => 'Màu sắc tùy chỉnh';

  @override
  String get themeApplyCustomColor => 'Áp dụng màu sắc';

  @override
  String get themeApplySettings => 'Áp dụng cài đặt';

  @override
  String get dataImportExport => 'Nhập khẩu và xuất dữ liệu';

  @override
  String get dataImportExportDesc =>
      'Nhập dữ liệu đầy đủ hoặc lịch trình đơn, hoặc xuất hiện tại / tất cả các lịch trình.';

  @override
  String get appBackupTitle => 'Sao lưu và khôi phục ứng dụng';

  @override
  String get appBackupSubtitle =>
      'Sao lưu hoặc khôi phục thời khóa biểu, lịch trình, cài đặt và trang trường học. Không bao gồm khóa API.';

  @override
  String get appBackupSheetSubtitle =>
      'Khôi phục đầy đủ sẽ thay thế dữ liệu ứng dụng hiện tại. Khóa AI API nằm trong bộ nhớ bảo mật và không được ghi vào tệp sao lưu.';

  @override
  String get restoreBackupFileTitle => 'Khôi phục từ tệp JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Chọn một tệp sao lưu Sked đầy đủ. Bạn sẽ xác nhận trước khi khôi phục.';

  @override
  String get restoreBackupTextTitle => 'Dán JSON sao lưu';

  @override
  String get restoreBackupTextSubtitle =>
      'Dán bản sao lưu đầy đủ và khôi phục dữ liệu ứng dụng hiện tại.';

  @override
  String get shareBackupTitle => 'Chia sẻ tệp sao lưu';

  @override
  String get shareBackupSubtitle =>
      'Xuất toàn bộ dữ liệu ứng dụng dưới dạng JSON. Khóa API bị loại trừ.';

  @override
  String get saveBackupTitle => 'Lưu tệp sao lưu';

  @override
  String get saveBackupSubtitle =>
      'Lưu bản sao lưu đầy đủ của ứng dụng vào tệp cục bộ.';

  @override
  String get copyBackupTitle => 'Sao chép văn bản sao lưu';

  @override
  String get copyBackupSubtitle =>
      'Hiển thị JSON sao lưu đầy đủ để bạn có thể sao chép hoặc lưu tạm thời.';

  @override
  String get restoreBackupConfirmTitle => 'Khôi phục bản sao lưu đầy đủ?';

  @override
  String get restoreBackupConfirmMessage =>
      'Thao tác này sẽ thay thế tất cả thời khóa biểu, lịch trình chung, cài đặt và trang trường học hiện tại. Khóa API không được nhập từ bản sao lưu; hãy nhập lại khóa trước khi phân tích thời khóa biểu lần nữa.';

  @override
  String get restoreBackupConfirmAction => 'Khôi phục sao lưu';

  @override
  String get restoreBackupSuccessMessage =>
      'Đã khôi phục bản sao lưu ứng dụng đầy đủ. Cần nhập lại khóa AI API.';

  @override
  String get restoreBackupFailureMessage =>
      'Khôi phục thất bại. Hãy kiểm tra nội dung bản sao lưu và thử lại.';

  @override
  String get openSourceLicenses => 'Giấy phép nguồn mở';

  @override
  String get openSourceLicensesDesc =>
      'Xem giấy phép cho các phụ thuộc Flutter và tài sản biểu tượng ứng dụng được gói.';

  @override
  String get checkForUpdates => 'Kiểm tra cập nhật';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Đã có phiên bản mới nhất ($version)';
  }

  @override
  String get currentVersionLabel => 'Phiên bản hiện tại';

  @override
  String get newVersionAvailable => 'Cập nhật có sẵn';

  @override
  String get latestVersionLabel => 'Phiên bản mới nhất';

  @override
  String get updateContentLabel => 'Cập nhật chi tiết';

  @override
  String get officialWebsite => 'Trang web chính thức';

  @override
  String get googlePlay => 'Chơi Google';

  @override
  String get cloudDrive => 'Động cơ đám mây';

  @override
  String get ignoreThisVersion => 'Bỏ qua phiên bản này';

  @override
  String get openUpdatesFailed => 'Không thể mở liên kết cập nhật';

  @override
  String get updateCheckFailedTitle => 'Kiểm tra cập nhật không thành công';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Kho lưu trữ GitHub';

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
  String get openGithubFailed => 'Không thể mở liên kết kho GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Không thể mở liên kết chính sách quyền riêng tư';

  @override
  String get selectPeriodTimeSet => 'Chọn thời gian thời gian';

  @override
  String get newItem => 'Mới';

  @override
  String get editPeriodTimeSet => 'Chỉnh sửa thiết lập thời gian giai đoạn';

  @override
  String get importTimetableFiles => 'Nhập lịch trình';

  @override
  String get importTimetableFilesDesc =>
      'Hỗ trợ một hoặc nhiều tệp lịch trình.';

  @override
  String get importTimetableText => 'Nhập lịch trình từ văn bản';

  @override
  String get importTimetableTextDesc =>
      'Dán nội dung JSON lịch trình và nhập nó.';

  @override
  String get shareTimetableFiles => 'Chia sẻ các tập tin lịch trình';

  @override
  String get shareTimetableFilesDesc => 'Chọn một hoặc nhiều lịch trình trước.';

  @override
  String get saveTimetableFiles => 'Lưu các tệp lịch trình';

  @override
  String get saveTimetableFilesDesc => 'Chọn một hoặc nhiều lịch trình trước.';

  @override
  String get exportTimetableText => 'Xuất lịch trình dưới dạng văn bản';

  @override
  String get exportTimetableTextDesc =>
      'Chọn một hoặc nhiều lịch trình, sau đó sao chép nội dung JSON.';

  @override
  String get jsonContent => 'Nội dung JSON';

  @override
  String get pasteJsonContentHint => 'Dán nội dung JSON để nhập.';

  @override
  String get jsonContentEmpty => 'Dán nội dung JSON trước.';

  @override
  String get copyText => 'Sao chép';

  @override
  String get copiedToClipboard => 'Sao chép vào clipboard';

  @override
  String get share => 'Chia sẻ';

  @override
  String get selectTimetablesToExport => 'Chọn lịch trình để xuất khẩu';

  @override
  String get selectTimetablesToImport => 'Chọn lịch trình để nhập';

  @override
  String timetableCourseCount(int count) {
    return ' $count các khóa học';
  }

  @override
  String get importAction => 'Nhập khẩu';

  @override
  String get importTimetableDialogTitle => 'Nhập lịch trình';

  @override
  String get chooseImportMethod => 'Chọn cách nhập khẩu';

  @override
  String get importAsNewTimetable => 'Nhập như lịch trình mới';

  @override
  String get replaceCurrentTimetable => 'Thay thế lịch trình hiện tại';

  @override
  String get importPeriodTimeSetDialogTitle => 'Nhập khẩu thời gian';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Tệp này chứa các tập hợp thời gian giai đoạn đóng gói. Bạn có muốn nhập và liên kết chúng không?';

  @override
  String get importBundledPeriodTimeSets => 'Nhập khẩu và liên kết';

  @override
  String get discardBundledPeriodTimeSets => 'Vứt bỏ các bộ gói';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Không có bộ thời gian giai đoạn hiện có, vì vậy các bộ thời gian giai đoạn đóng gói không thể bị loại bỏ.';

  @override
  String savedToPath(Object path) {
    return 'Lưu vào $path';
  }

  @override
  String get saveCancelled => 'Lưu hủy';

  @override
  String get fileSaveRestrictedTitle => 'Lưu tập tin bị hạn chế';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Hệ thống không thể lưu tệp. Bạn có thể thử lại hoặc sử dụng chia sẻ thay vào đó.';

  @override
  String get retrySave => 'Thử lưu lại';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Bật truy cập tệp trong cài đặt hệ thống, sau đó quay lại và thử xuất lại.';

  @override
  String get openSettings => 'Cài đặt mở';

  @override
  String get browserDownloadRestrictedTitle =>
      'Tải xuống trình duyệt bị hạn chế';

  @override
  String get browserDownloadRestrictedMessage =>
      'Trình duyệt này không hỗ trợ lưu trực tiếp vào tệp cục bộ. Kiểm tra quyền tải xuống trình duyệt hoặc sử dụng chia sẻ tập tin thay vào đó.';

  @override
  String get switchToShare => 'Sử dụng chia sẻ thay vì';

  @override
  String get fileSaveFailedTitle => 'Lưu tập tin không thành công';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Không thể viết vào đường dẫn hiện tại. Thư mục tiêu có thể được bảo vệ, tệp có thể đang được sử dụng hoặc đường dẫn có thể không thể viết được.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Hệ thống không thể lưu tệp. Bạn có thể thử lại, kiểm tra cài đặt hệ thống hoặc sử dụng chia sẻ tệp thay vào đó.';

  @override
  String get retryLater => 'Thử lại sau';

  @override
  String get exportSwitchedToShare => 'Chuyển sang chia sẻ tệp để xuất khẩu';

  @override
  String get saveFailedRetry => 'Lưu thất bại. Vui lòng thử lại sau.';

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
  String get appInstanceBlockedTitle => 'Sked đang mở';

  @override
  String get appInstanceBlockedMessage =>
      'Một cửa sổ Sked hoặc thẻ trình duyệt khác đang sử dụng dữ liệu cục bộ của bạn. Hãy đóng cửa sổ hoặc thẻ đó rồi thử lại.';

  @override
  String get appInstanceLeaseFailedTitle => 'Dữ liệu cục bộ không khả dụng';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked không thể xác minh quyền truy cập độc quyền vào dữ liệu cục bộ. Dữ liệu của bạn chưa được mở hoặc thay đổi. Hãy kiểm tra quyền truy cập bộ nhớ rồi thử lại.';

  @override
  String get savingChanges => 'Đang lưu thay đổi...';

  @override
  String get showApiKey => 'Hiện khóa API';

  @override
  String get hideApiKey => 'Ẩn khóa API';

  @override
  String get importFailedCheckContent =>
      'Nhập không thành công. Xin vui lòng kiểm tra nội dung tập tin.';

  @override
  String get noImportableTimetables =>
      'Không có lịch sử sử dụng được tìm thấy trong tệp nhập khẩu.';

  @override
  String importedTimetablesCount(int count) {
    return 'Nhập $count lịch trình';
  }

  @override
  String get periodTimesTitle => 'Thời gian';

  @override
  String get importExport => 'Nhập khẩu và xuất khẩu';

  @override
  String get importPeriodTemplate => 'Mẫu thời gian nhập khẩu';

  @override
  String get importPeriodTemplateText => 'Nhập mẫu giai đoạn từ văn bản';

  @override
  String get sharePeriodTemplate => 'Mẫu thời gian chia sẻ';

  @override
  String get saveTemplateToFile => 'Lưu mẫu vào tệp';

  @override
  String get exportPeriodTemplateText => 'Xuất mẫu giai đoạn dưới dạng văn bản';

  @override
  String get deletePeriodTimeSet => 'Xóa thiết lập thời gian giai đoạn';

  @override
  String get periodTimeSetName => 'Tên thiết lập thời gian giai đoạn';

  @override
  String get addOnePeriod => 'Thêm thời gian';

  @override
  String periodNumberLabel(int index) {
    return 'Thời gian $index';
  }

  @override
  String get deleteThisPeriod => 'Xóa giai đoạn này';

  @override
  String durationMinutes(int minutes) {
    return 'Thời gian $minutes phút';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Khoảng cách từ $minutes phút trước';
  }

  @override
  String get endTimeMustBeLater =>
      'Thời gian kết thúc phải trễ hơn thời gian bắt đầu';

  @override
  String get periodOverlapPrevious =>
      'Giai đoạn này chồng chéo với giai đoạn trước';

  @override
  String get periodTimesSaved => 'Thời gian tiết kiệm';

  @override
  String get deletePeriodTimeSetTitle => 'Xóa thiết lập thời gian giai đoạn';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Xóa \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'thời gian thời gian hiện tại';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Nhập $count thời gian giai đoạn';
  }

  @override
  String get periodFilePermissionTitle => 'File permission cần thiết';

  @override
  String get androidFilePermissionMessage =>
      'Android export yêu cầu quyền truy cập tệp. Cho phép tiếp tục tiết kiệm.';

  @override
  String get reauthorize => 'Chấp thuận lại';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Giấy phép bị từ chối vĩnh viễn';

  @override
  String get permissionSettingsExportMessage =>
      'Bật truy cập tệp trong cài đặt hệ thống, sau đó quay lại và thử xuất lại.';

  @override
  String get privacyPolicyTitle => 'Chính sách bảo mật';

  @override
  String get privacyPolicyEntryDesc =>
      'Tìm hiểu cách ứng dụng xử lý lưu trữ cục bộ, cấu hình trang web trường, nhập / xuất tệp, phân tích trang web và liên kết bên ngoài.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Phiên bản được chấp nhận: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked là công cụ thời khóa biểu ưu tiên lưu trữ cục bộ. Thời khóa biểu, bộ thời gian và cấu hình trang web trường học chỉ được lưu trên thiết bị hoặc trình duyệt của bạn và không bao giờ được tự động tải lên. Ứng dụng chỉ xử lý dữ liệu khi bạn chủ động kích hoạt các thao tác như nhập, phân tích trang web, chia sẻ hoặc mở liên kết bên ngoài. Chính sách bảo mật đầy đủ có sẵn trực tuyến.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Lưu trữ địa phương';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Nhập khẩu và xuất khẩu';

  @override
  String get privacyPolicyImportExportBody =>
      'Ứng dụng đọc hoặc viết các tệp JSON lịch trình, các tệp JSON trang web trường học và các tệp mẫu thời gian chỉ khi bạn chọn rõ ràng một tệp hoặc bắt đầu hành động xuất. Nhập các tệp này là một hoạt động cục bộ trừ khi bạn cũng chọn phân tích trang web. Lấy một danh sách mô hình tùy chỉnh cũng là một hành động mạng rõ ràng và chỉ liên hệ với điểm cuối tùy chỉnh mà bạn cấu hình.';

  @override
  String get privacyPolicySharingTitle => 'Chia sẻ';

  @override
  String get privacyPolicySharingBody =>
      'Khi bạn sử dụng chia sẻ rõ ràng, ứng dụng sẽ truyền tệp xuất đến trang chia sẻ hệ thống hoặc ứng dụng mục tiêu bạn chọn. Cách xử lý tập tin đó sau đó phụ thuộc vào ứng dụng hoặc dịch vụ mục tiêu mà bạn đã chọn.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Liên kết bên ngoài';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Khi bạn mở các liên kết bên ngoài như kho GitHub, ứng dụng sẽ chuyển hành động ra trình duyệt của bạn hoặc ứng dụng bên ngoài khác. Xử lý dữ liệu sau thời điểm đó được quản lý bởi bên thứ ba bạn mở.';

  @override
  String get privacyPolicyNoCollectionTitle =>
      'Những gì ứng dụng không thu thập';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Ứng dụng không yêu cầu tài khoản Sked và không cho phép phân tích, nhận dạng quảng cáo hoặc sao lưu đám mây. Nó cũng không cung cấp một trường chuyên dụng để thu thập mật khẩu tài khoản trường học. Nếu bạn đăng nhập vào trang web của trường bên trong ứng dụng, tương tác đó xảy ra trên trang trường bạn đã mở.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Phân tích trang web';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Khi bạn dùng nhập trang web của trường hoặc phân tích văn bản thời khóa biểu / HTML đã dán, ứng dụng trước tiên chuẩn bị và làm sạch nội dung cục bộ, rồi gửi văn bản thời khóa biểu, văn bản trang hoặc nội dung HTML đã gửi, tiêu đề và URL trang tùy chọn, ngôn ngữ hiện tại của ứng dụng và nội dung prompt của trình phân tích tới endpoint tương thích OpenAI mà bạn đã cấu hình. Việc lấy danh sách mô hình cũng yêu cầu cùng endpoint đó. Sked không cung cấp endpoint phân tích tích hợp và không gửi yêu cầu phân tích tới backend phân tích thời khóa biểu do nhà phát triển kiểm soát. Endpoint tùy chỉnh và mọi dịch vụ upstream có thể lưu trữ, chuyển tiếp, giới hạn, xóa hoặc xử lý dữ liệu theo cách khác theo quy tắc của nhà cung cấp dịch vụ mà bạn chọn. Nếu bạn dùng Base URL http://, chỉ dùng trên thiết bị, mạng và dịch vụ endpoint đáng tin cậy, vì nội dung và khóa API có thể không được bảo vệ bằng mã hóa truyền tải.';

  @override
  String get privacyPolicyUpdatesTitle => 'Cập nhật chính sách';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Phiên bản chính sách bảo mật hiện tại là $version. Nếu một phiên bản mới hơn thay đổi cách xử lý dữ liệu, ứng dụng có thể yêu cầu bạn đọc và đồng ý với chính sách cập nhật một lần nữa.';
  }

  @override
  String get privacyGateTitle =>
      'Vui lòng đồng ý với chính sách bảo mật trước khi sử dụng ứng dụng';

  @override
  String get privacyGateSummaryStorage =>
      'Lịch trình, các bộ thời gian và cấu hình trang web trường chỉ được lưu trữ tại địa phương và không được tự động tải lên máy chủ nhà phát triển.';

  @override
  String get privacyGateSummaryImportExport =>
      'Nhập, xuất và chia sẻ chỉ xảy ra khi bạn bắt đầu chúng một cách rõ ràng; Phân tích trang web chỉ gửi nội dung nén mà bạn gửi đến điểm cuối phân tích được cấu hình của bạn, và bạn có thể xem xét lịch trình phân tích trước khi lưu.';

  @override
  String get privacyGateSummaryUpdates =>
      'Nếu một phiên bản mới hơn thay đổi cách xử lý dữ liệu, ứng dụng có thể yêu cầu bạn xem lại chính sách bảo mật được cập nhật.';

  @override
  String get schoolWebImportEntry => 'Nhập từ trang web trường';

  @override
  String get schoolWebImportEntryDesc =>
      'Nhập trang lịch trình hiện tại từ trang web trường.';

  @override
  String get schoolSitesManageEntry => 'Quản lý trang web trường';

  @override
  String get schoolSitesManageEntryDesc =>
      'Thêm, chỉnh sửa và xóa URL đăng nhập trường, với nhập và xuất JSON.';

  @override
  String get schoolSitesPageTitle => 'Quản lý trang web trường';

  @override
  String get schoolSitesImportJson => 'Nhập JSON trường học';

  @override
  String get schoolSitesShareJson => 'Chia sẻ JSON trường học';

  @override
  String get schoolSitesSaveJson => 'Lưu JSON trường học';

  @override
  String get schoolSitesSaved => 'Trang web trường được lưu';

  @override
  String get schoolSitesImported => 'Các trang web trường học nhập khẩu';

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
  String get schoolSitesEmpty => 'Chưa có cấu hình trang web của trường.';

  @override
  String get schoolSitesNameLabel => 'Tên trường';

  @override
  String get schoolSitesLoginUrlLabel => 'Đăng nhập URL';

  @override
  String get schoolSitesAdd => 'Thêm trường';

  @override
  String get schoolSitesEdit => 'Chỉnh sửa trường';

  @override
  String get schoolSitesDeleteTitle => 'Xóa trường';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Xóa \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Điền vào tên trường và URL đăng nhập trước.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Nhập bằng cách dán nội dung trang lịch trình';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Dán mã nguồn hoặc nội dung trang thô chứa thông tin lịch trình bằng tay.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Phân tích lịch trình từ nội dung trang';

  @override
  String get schoolHtmlImportUrlLabel => 'URL nguồn (tùy chọn)';

  @override
  String get schoolHtmlImportTitleLabel => 'Tiêu đề trang (tùy chọn)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Nội dung trang';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Dán mã nguồn hoặc nội dung trang thô chứa thông tin lịch trình ở đây.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Bất kỳ nội dung nào chứa thông tin lịch trình có thể được phân tích và nhập khẩu, không chỉ HTML.';

  @override
  String get schoolHtmlImportCompress => 'Chuẩn bị nội dung';

  @override
  String get schoolHtmlImportCompressed => 'Nội dung đã chuẩn bị';

  @override
  String get schoolHtmlImportCompressFirst => 'Hãy chuẩn bị nội dung trước.';

  @override
  String get schoolHtmlImportSubmit => 'Phân tích và nhập khẩu';

  @override
  String get schoolImportContentTruncated =>
      'Trang này đã đạt giới hạn nhập an toàn. Chỉ phần đã thu thập sẽ được gửi để phân tích.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Phân tích có thể mất một thời gian. Xin đợi.';

  @override
  String get schoolHtmlImportEmpty => 'Dán trang HTML trước.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Trở lại trang web';

  @override
  String get schoolWebImportPageTitle => 'Nhập trang web trường học';

  @override
  String get schoolWebImportPreview => 'Nhập xem trước';

  @override
  String schoolWebImportCourseCount(int count) {
    return ' $count các khóa học';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return ' $count thời gian';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Tiêu đề trang';

  @override
  String get schoolWebImportParserUsed => 'Phân tích';

  @override
  String get schoolWebImportWarnings => 'Nhập ghi chú';

  @override
  String get schoolWebImportParserDetails => 'Chi tiết phân tích';

  @override
  String get schoolWebImportExpandParserDetails => 'Mở rộng chi tiết phân tích';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Thu gọn chi tiết phân tích';

  @override
  String get schoolWebImportOpenPageHint =>
      'Đăng nhập vào trang web của trường trong ứng dụng, sau đó điều hướng đến trang lịch trình thủ công.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Nền tảng này chưa hỗ trợ đăng nhập web nhúng. Vui lòng sử dụng một nền tảng với hỗ trợ WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Chọn trường';

  @override
  String get schoolWebImportNoSchools =>
      'Không có cấu hình trường có sẵn. Kiểm tra school_sites.json trước.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Không thể tải cấu hình trường. Kiểm tra định dạng tập tin JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Nhập trang hiện tại';

  @override
  String get schoolWebImportLoadingPage => 'Đang tải trang…';

  @override
  String get schoolWebImportParsing => 'Phân tích trang hiện tại...';

  @override
  String get schoolWebImportLoadFailed =>
      'Page load không thành công. Xin vui lòng làm mới hoặc thử lại sau.';

  @override
  String get schoolWebImportUnknownOrigin => 'Trang web không xác định';

  @override
  String get schoolWebImportExitTitle => 'Thoát trình duyệt?';

  @override
  String get schoolWebImportExitMessage =>
      'Trang sẽ đóng lại. Mọi nội dung bạn chưa nhập sẽ bị mất.';

  @override
  String get schoolWebImportExitConfirm => 'Thoát';

  @override
  String get schoolWebImportEmptyPage =>
      'Nội dung trang hiện tại trống và chưa thể nhập được.';

  @override
  String get schoolWebImportSuccess => 'Lịch trình web nhập khẩu';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Nguồn parser';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Tùy chỉnh OpenAI tương thích';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Phân tích tương thích OpenAI tùy chỉnh';

  @override
  String get schoolImportParserCustomPromptTitle => 'Tùy chỉnh nhắc nhở';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Chỉnh sửa built-in parser prompt ở đây. Thay đổi chỉ ảnh hưởng đến trình phân tích tương thích OpenAI tùy chỉnh.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Lời nhắc tích hợp được tải ở đây theo mặc định. Xóa nó để trở lại phiên bản tích hợp.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Đặt lại lời nhắc mặc định';

  @override
  String get schoolImportParserBaseUrl => 'URL cơ sở';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL phải là URL HTTP hoặc HTTPS có máy chủ.';

  @override
  String get schoolImportParserApiKey => 'Khóa API';

  @override
  String get schoolImportParserModel => 'Mô hình';

  @override
  String get schoolImportParserFetchModels => 'Lấy danh sách mô hình';

  @override
  String get schoolImportParserFetchingModels => 'Lấy mô hình. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Không có mô hình nào được trả lại bởi điểm cuối.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Không thể tải danh sách mô hình. Hãy kiểm tra điểm cuối rồi thử lại.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Lấy các mô hình $count';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Sử dụng điểm cuối HTTP không mã hóa?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'Khóa API và nội dung thời khóa biểu có thể bị đọc hoặc thay đổi trong quá trình truyền. Chỉ tiếp tục nếu bạn tin cậy thiết bị, mạng và điểm cuối này. Sự chấp thuận có hiệu lực cho đến khi bạn đóng Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Cấu hình parser tùy chỉnh không hoàn chỉnh. Điền vào URL cơ sở, khóa API và mô hình trước.';

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
    return 'Phân tích: Tùy chỉnh ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Xem chính sách bảo mật đầy đủ';

  @override
  String get privacyAgreeAndContinue => 'Đồng ý và tiếp tục';

  @override
  String get privacyDecline => 'từ chối';

  @override
  String get privacyDeclineWebHint =>
      'Môi trường trình duyệt này không cho phép ứng dụng đóng trang cho bạn. Nếu bạn không đồng ý, vui lòng tự đóng tab hoặc cửa sổ này.';

  @override
  String get defaultPeriodTimeSetName => 'Thời gian mặc định';

  @override
  String get periodTimeSetFallbackName => 'Thời gian';

  @override
  String get untitledTimetableName => 'Thời gian biểu không có tiêu đề';

  @override
  String get newTimetableName => 'Thời gian mới';

  @override
  String get newPeriodTimeSetName => 'Thiết lập thời gian giai đoạn mới';

  @override
  String get emptyTimetableName => 'Thời gian biểu trống';

  @override
  String importedPeriodTimeSetName(Object name) {
    return ' $name thời gian';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Loại tập tin nhập không phù hợp.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Phiên bản tập tin nhập này chưa được hỗ trợ.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Không có thời gian được tìm thấy trong tệp nhập khẩu.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Xin vui lòng chọn ít nhất một lịch trình.';

  @override
  String get noExportableTimetableMessage =>
      'Không có lịch trình có sẵn để xuất khẩu.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Thay thế lịch trình hiện tại chỉ hỗ trợ chọn một lịch trình.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Không có lịch trình hiện tại để thay thế.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Bộ thời gian giai đoạn này vẫn được sử dụng bởi $count lịch trình (s). Đặt lại trước khi xóa.';
  }

  @override
  String get weekdayMonday => 'Thứ Hai';

  @override
  String get weekdayTuesday => 'Thứ ba';

  @override
  String get weekdayWednesday => 'Thứ Tư';

  @override
  String get weekdayThursday => 'Thứ Năm';

  @override
  String get weekdayFriday => 'Thứ Sáu';

  @override
  String get weekdaySaturday => 'Thứ bảy';

  @override
  String get weekdaySunday => 'Chủ nhật';

  @override
  String get weekdayShortMonday => 'Thứ Hai';

  @override
  String get weekdayShortTuesday => 'Thứ ba';

  @override
  String get weekdayShortWednesday => 'Thứ Tư';

  @override
  String get weekdayShortThursday => 'Thứ Năm';

  @override
  String get weekdayShortFriday => 'Thứ Sáu';

  @override
  String get weekdayShortSaturday => 'Thứ bảy';

  @override
  String get weekdayShortSunday => 'Mặt trời';

  @override
  String get monthJanuary => 'Tháng Jan';

  @override
  String get monthFebruary => 'Tháng Hai';

  @override
  String get monthMarch => 'Tháng 3';

  @override
  String get monthApril => 'Tháng Tư';

  @override
  String get monthMay => 'Tháng Năm';

  @override
  String get monthJune => 'Tháng Sáu';

  @override
  String get monthJuly => 'Tháng Bảy';

  @override
  String get monthAugust => 'Tháng Tám';

  @override
  String get monthSeptember => 'Tháng 9';

  @override
  String get monthOctober => 'Tháng Mười';

  @override
  String get monthNovember => 'Tháng Mười Một';

  @override
  String get monthDecember => 'Tháng Mười Hai';

  @override
  String get semesterWeeksWholeTerm => 'Tất cả học kỳ';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Tuần $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Tuần $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Chọn chế độ bắt đầu';

  @override
  String get firstLaunchSubtitle =>
      'Chọn không gian làm việc bạn dùng nhiều nhất. Bạn có thể đổi chế độ sau.';

  @override
  String get firstLaunchStudentDesc =>
      'Quản lý thời khóa biểu, khóa học, tuần, tiết học và nhập dữ liệu.';

  @override
  String get firstLaunchGeneralDesc =>
      'Quản lý danh mục, sự kiện, nhắc nhở và dữ liệu JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Bắt đầu với thời khóa biểu';

  @override
  String get firstLaunchStartGeneral => 'Bắt đầu với lịch trình';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Khi chọn không gian làm việc ban đầu, bạn xác nhận đã đọc và đồng ý với ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Chính sách quyền riêng tư';

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
  String get today => 'Hôm nay';

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
      'Chế độ xem, thanh công cụ, định dạng ngày và thêm nhanh';

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
  String get viewWeek => 'Tuần';

  @override
  String get viewDay => 'Ngày';

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
  String get developerModeTitle => 'Chế độ nhà phát triển';

  @override
  String get developerModeDescription =>
      'Công cụ thêm dữ liệu mẫu đầy đủ để kiểm tra giao diện và thao tác.';

  @override
  String get developerSampleLanguage => 'Ngôn ngữ dữ liệu mẫu';

  @override
  String get developerSampleChinese => 'Tiếng Trung';

  @override
  String get developerSampleEnglish => 'Tiếng Anh';

  @override
  String get developerSampleDataDescription =>
      'Thêm một thời khóa biểu cùng các danh mục và sự kiện mà không thay thế dữ liệu hiện có.';

  @override
  String get developerAddSampleData => 'Thêm dữ liệu mẫu';

  @override
  String get developerSampleDataAdded =>
      'Đã thêm thời khóa biểu và sự kiện mẫu.';

  @override
  String get developerModeLongPressHint =>
      'Nhấn giữ 3 giây để mở chế độ nhà phát triển';

  @override
  String get collapseWorkspaceNavigation =>
      'Thu gọn điều hướng không gian làm việc';

  @override
  String get expandWorkspaceNavigation =>
      'Mở rộng điều hướng không gian làm việc';

  @override
  String get schoolWebImportExitBrowser => 'Thoát trình duyệt trong ứng dụng';

  @override
  String get schoolWebImportEditAddress => 'Chỉnh sửa địa chỉ';

  @override
  String get schoolWebImportAddressLabel => 'Địa chỉ web';

  @override
  String get schoolWebImportOpenAddress => 'Mở';

  @override
  String get schoolWebImportAddressInvalid =>
      'Nhập địa chỉ HTTP hoặc HTTPS có máy chủ.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Trang web này yêu cầu một cửa sổ mới không thể mở trên thiết bị này.';

  @override
  String get schoolWebImportSecureConnection => 'Kết nối bảo mật';

  @override
  String get schoolWebImportInsecureConnection => 'Kết nối không bảo mật';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Mở trang đăng nhập của trường?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Quá trình đăng nhập của trường có thể gửi thông tin xác thực qua biểu mẫu hoặc lệnh chuyển hướng của máy chủ đến trường và các nhà cung cấp đăng nhập. Android không thể tạm dừng mọi lần truyền như vậy để xác nhận riêng từng đích. Chỉ tiếp tục nếu bạn tin cậy các bên này trong phiên nhập này:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Mở trang đăng nhập trường học không an toàn?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Trang đăng nhập trường học này sử dụng HTTP. Bất kỳ ai có thể theo dõi hoặc can thiệp vào kết nối này đều có thể đọc hoặc thay đổi thông tin xác thực và nội dung trang của bạn. Chỉ tiếp tục nếu bạn chấp nhận rủi ro này đối với:\n\n$origin';
  }
}
