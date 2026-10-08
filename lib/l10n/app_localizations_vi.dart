// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Sked';

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
  String get schoolImportResultEditorTitle => 'Chỉnh sửa kết quả phân tích';

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
  String get schoolImportExpandWarnings => 'Mở rộng cảnh báo nhập';

  @override
  String get schoolImportCollapseWarnings => 'Thu gọn cảnh báo nhập';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Một số môn học kéo dài đến tuần $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Thay thế thời khóa biểu hiện tại?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Thời khóa biểu được nhập sẽ thay thế thời khóa biểu hiện tại.';

  @override
  String get createTimetable => 'Thời gian mới';

  @override
  String get jumpToWeek => 'Nhảy đến tuần';

  @override
  String get timetable => 'Thời gian';

  @override
  String get themeWorkspaceSchedule => 'Lịch';

  @override
  String get timetableName => 'Tên lịch trình';

  @override
  String get timetableNameRequired => 'Vui lòng nhập tên thời khóa biểu';

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
  String get settingsSectionTimetable => 'Thời khóa biểu';

  @override
  String get settingsSectionGeneralSchedule => 'Lịch chung';

  @override
  String get settingsSectionAppearance => 'Giao diện';

  @override
  String get settingsSectionApp => 'Ứng dụng';

  @override
  String get settingsSectionWorkspace => 'Không gian làm việc';

  @override
  String get settingsSectionAppearanceLanguage => 'Giao diện và ngôn ngữ';

  @override
  String get settingsSectionDataSecurity => 'Dữ liệu và bảo mật';

  @override
  String get settingsSectionAbout => 'Giới thiệu Sked';

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
  String get timetableHorizontalLayoutSection => 'Bố cục ngang và cử chỉ';

  @override
  String get fitDaySelectorToWidth => 'Điều chỉnh bộ chọn ngày vừa màn hình';

  @override
  String get fitDaySelectorToWidthHint =>
      'Hiển thị đủ bảy ngày trên màn hình khi có thể. Tắt để dùng chiều rộng cố định và cuộn ngang.';

  @override
  String get fitWeekColumnsToWidth => 'Điều chỉnh các cột tuần vừa màn hình';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Hiển thị đủ bảy cột thời khóa biểu trên màn hình khi có thể. Tắt để dùng chiều rộng cố định và cuộn ngang.';

  @override
  String get enableWeekSwipeNavigation => 'Vuốt để đổi tuần';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Vuốt sang trái hoặc phải để đổi tuần. Khi dùng chiều rộng cố định, hãy cuộn đến mép rồi kéo tiếp.';

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
  String get outlineWidthUnit => 'px';

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
  String get microsoftStoreUpdates =>
      'Các bản cập nhật do Microsoft Store quản lý';

  @override
  String get includePrereleaseUpdates => 'Nhận bản cập nhật phát hành trước';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Bao gồm các phiên bản Alpha, Beta và RC có thể chưa ổn định. Khi tắt, chỉ cung cấp các phiên bản ổn định.';

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
  String get googlePlay => 'Google Play';

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
      'Không thể lấy phiên bản mới nhất từ GitHub. Bạn vẫn có thể mở trang GitHub Releases bên dưới.';

  @override
  String get githubRepository => 'Kho lưu trữ GitHub';

  @override
  String get googlePlayStoreDesc => 'Xem Sked trên Google Play';

  @override
  String get openGooglePlayFailed => 'Không thể mở Google Play';

  @override
  String get starSkedOnGithub => 'Tặng Sked một sao trên GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Mở kho mã nguồn của dự án và tặng Sked một sao';

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
  String get periodTimesUnsavedExitTitle => 'Thay đổi chưa được lưu';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Không thể lưu những thay đổi mới nhất về giờ học. Bạn có thể thử lại, tiếp tục chỉnh sửa hoặc bỏ các thay đổi.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Một số giờ học không hợp lệ. Hãy sửa trước khi lưu, hoặc bỏ các thay đổi và thoát.';

  @override
  String get discardChangesAndExit => 'Bỏ thay đổi và thoát';

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
      'Trên các nền tảng cài đặt ứng dụng, Sked lưu dữ liệu thời khóa biểu, lịch chung, các cài đặt liên quan và cấu hình trang web trường học có thể chỉnh sửa trong thư mục hỗ trợ ứng dụng của hệ điều hành; bản chạy trên trình duyệt dùng bộ nhớ của trình duyệt. Các tệp do phiên bản trước ghi vào thư mục Tài liệu của người dùng vẫn được giữ nguyên, nhưng không được tự động đọc hoặc di chuyển. Để giữ lại dữ liệu đó, hãy xuất bản sao lưu toàn bộ ứng dụng từ phiên bản cũ trước khi nâng cấp, rồi khôi phục sau đó. Cài đặt AI API được lưu cục bộ; khóa API tùy chỉnh được lưu qua lớp lưu trữ an toàn của nền tảng nếu có. Bản sao lưu toàn bộ ứng dụng không chứa khóa API tùy chỉnh. Ứng dụng không tự động tải dữ liệu cục bộ này lên máy chủ do nhà phát triển kiểm soát.';

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
  String get schoolSitesImportPreviewTitle =>
      'Kiểm tra dữ liệu nhập trang web trường học';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount trang web hợp lệ, $invalidCount mục không hợp lệ.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Tệp chứa danh sách trang web trường học trống.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Mục $position không hợp lệ và sẽ bị bỏ qua.';
  }

  @override
  String get schoolSitesImportMerge => 'Hợp nhất';

  @override
  String get schoolSitesImportReplace => 'Thay thế';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Thay thế các trang web trường học hiện tại?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Thao tác này sẽ xóa $currentCount trang web hiện tại và lưu $importedCount trang web được nhập. Không thể hoàn tác.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Dữ liệu trang web trường học cần được khôi phục';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked không thể đọc tệp trang web trường học hoặc bản sao lưu của tệp. Các bản sao được bảo vệ đã được tạo trước khi chặn ghi dữ liệu.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Không thể truy cập nơi lưu trang web trường học';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Hiện Sked không thể truy cập nơi lưu trang web trường học. Hãy kiểm tra quyền truy cập bộ nhớ hoặc tình trạng thiết bị rồi thử lại. Dữ liệu trang web hiện tại sẽ không bị ghi đè.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Các tệp khôi phục hoặc vị trí lưu trữ bị ảnh hưởng được liệt kê bên dưới. Hãy giữ nguyên các tệp cho đến khi khôi phục xong danh sách trang web.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Bắt đầu không có trang web trường học';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Bắt đầu với danh sách trang web trường học trống?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Các bản sao được bảo vệ sẽ được giữ lại, nhưng Sked sẽ tạo một tệp trang web trường học mới và trống. Chỉ tiếp tục nếu bạn không muốn thử khôi phục lại trước.';

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
      'Cấu hình trình phân tích tùy chỉnh chưa đầy đủ. Hãy điền URL cơ sở, khóa API và mô hình trước.';

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
  String get schoolImportParserSettingsTitle => 'API phân tích thời khóa biểu';

  @override
  String get schoolImportParserSettingsDesc =>
      'Cấu hình API tương thích OpenAI để nhập thời khóa biểu, không phải để thiết lập trợ lý trò chuyện.';

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
      'Khóa API tùy chỉnh được lưu qua lớp lưu trữ an toàn của nền tảng nếu có. Chỉ dùng thông tin xác thực của trình phân tích tùy chỉnh và các điểm cuối HTTP trên thiết bị, trình duyệt và mạng mà bạn tin cậy.';

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
  String get clearAppData => 'Xóa dữ liệu';

  @override
  String get clearAppDataDesc =>
      'Xóa vĩnh viễn toàn bộ dữ liệu Sked cục bộ và thoát ứng dụng';

  @override
  String get clearAppDataConfirmTitle => 'Xóa toàn bộ dữ liệu Sked?';

  @override
  String get clearAppDataConfirmMessage =>
      'Thao tác này sẽ xóa vĩnh viễn thời khóa biểu, lịch, cài đặt, trang web trường học, bản sao lưu cục bộ, bản sao khôi phục và khóa AI API, sau đó thoát Sked. Các tệp bạn đã xuất ra nơi khác sẽ không bị xóa. Không thể hoàn tác.';

  @override
  String get clearAppDataAction => 'Xóa dữ liệu và thoát';

  @override
  String get clearAppDataFailed =>
      'Không thể xóa toàn bộ dữ liệu cục bộ. Sked sẽ vẫn mở để bạn có thể thử lại.';

  @override
  String get clearAppDataExitFailed =>
      'Dữ liệu cục bộ đã được xóa, nhưng Sked không thể thoát. Hãy đóng ứng dụng thủ công trước khi sử dụng lại.';

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
  String get generalSchedule => 'Lịch chung';

  @override
  String get studentTimetable => 'Thời khóa biểu';

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
  String get switchMode => 'Chuyển chế độ';

  @override
  String get generalScheduleComingSoon => 'Lịch chung sắp ra mắt';

  @override
  String get switchToStudentTimetable => 'Chuyển sang thời khóa biểu';

  @override
  String get mySchedule => 'Lịch của tôi';

  @override
  String get today => 'Hôm nay';

  @override
  String get addEvent => 'Thêm sự kiện';

  @override
  String get editEvent => 'Chỉnh sửa sự kiện';

  @override
  String get eventTitle => 'Tiêu đề';

  @override
  String get eventTitleRequired => 'Vui lòng nhập tiêu đề';

  @override
  String get eventStartTime => 'Giờ bắt đầu';

  @override
  String get eventEndTime => 'Giờ kết thúc';

  @override
  String get eventDate => 'Ngày';

  @override
  String get eventTime => 'Thời gian';

  @override
  String get eventNotes => 'Ghi chú';

  @override
  String get eventColor => 'Màu';

  @override
  String get eventRecurrence => 'Lặp lại';

  @override
  String get recurrenceNone => 'Không lặp lại';

  @override
  String get recurrenceWeekly => 'Hằng tuần';

  @override
  String get recurrenceEndDate => 'Ngày kết thúc';

  @override
  String get recurrenceNoEndDate => 'Không có ngày kết thúc';

  @override
  String get recurrenceSetEndDate => 'Đặt';

  @override
  String get recurrenceChangeEndDate => 'Thay đổi';

  @override
  String get repeatsWeekly => 'Lặp lại hằng tuần';

  @override
  String recurrenceUntil(Object date) {
    return 'Đến $date';
  }

  @override
  String get switchToGeneralSchedule => 'Chuyển sang lịch chung';

  @override
  String get generalDisplaySettings => 'Cài đặt hiển thị chung';

  @override
  String get generalDisplaySettingsDesc =>
      'Chế độ xem, thanh công cụ, định dạng ngày và thêm nhanh';

  @override
  String get closePopupOnOutsideTap => 'Đóng cửa sổ bật lên khi chạm bên ngoài';

  @override
  String get showGridLines => 'Hiển thị đường lưới';

  @override
  String get generalScheduleImportExport => 'Nhập và xuất danh mục';

  @override
  String get generalScheduleImportExportDesc =>
      'Nhập hoặc chia sẻ danh mục lịch';

  @override
  String get importGeneralSchedules => 'Nhập danh mục';

  @override
  String get importGeneralSchedulesDesc => 'Đọc danh mục từ tệp JSON';

  @override
  String get shareGeneralSchedules => 'Chia sẻ danh mục';

  @override
  String get shareGeneralSchedulesDesc => 'Chia sẻ danh mục dưới dạng tệp JSON';

  @override
  String get saveGeneralSchedules => 'Lưu danh mục';

  @override
  String get saveGeneralSchedulesDesc => 'Lưu danh mục dưới dạng tệp JSON';

  @override
  String get selectSchedulesToExport => 'Chọn danh mục để xuất';

  @override
  String get selectSchedulesToImport => 'Chọn danh mục để nhập';

  @override
  String generalScheduleEventCount(int count) {
    return 'Sự kiện: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Đã nhập $count danh mục';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Thêm dữ liệu nhập thành danh mục mới hay thay thế danh mục hiện có?';

  @override
  String get addAsNewSchedule => 'Thêm thành danh mục mới';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Vui lòng chọn ít nhất một danh mục.';

  @override
  String get noExportableScheduleMessage => 'Không có danh mục để xuất.';

  @override
  String get noSchedulesInImportMessage => 'Tệp nhập không chứa danh mục nào.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Chỉ chọn một danh mục được nhập để thay thế.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Danh mục đích đã chọn không khả dụng.';

  @override
  String get calendars => 'Danh mục';

  @override
  String get calendar => 'Danh mục';

  @override
  String get viewWeek => 'Tuần';

  @override
  String get viewDay => 'Ngày';

  @override
  String get viewList => 'Danh sách';

  @override
  String get viewMonth => 'Tháng';

  @override
  String visibleCategoryCount(int count) {
    return '$count danh mục';
  }

  @override
  String get noVisibleCategories => 'Không có danh mục hiển thị';

  @override
  String get selectCategoryToReplace => 'Chọn danh mục cần thay thế';

  @override
  String get replaceCategory => 'Thay thế danh mục';

  @override
  String get deleteEventTitle => 'Xóa sự kiện';

  @override
  String get deleteEventConfirmation => 'Sự kiện này sẽ bị xóa vĩnh viễn.';

  @override
  String get deleteRecurringEventTitle => 'Xóa sự kiện lặp lại';

  @override
  String get eventDuplicated => 'Đã nhân bản sự kiện';

  @override
  String get searchEvents => 'Tìm sự kiện';

  @override
  String get clearSearch => 'Xóa tìm kiếm';

  @override
  String get filterByColor => 'Lọc theo màu';

  @override
  String get allColors => 'Tất cả màu';

  @override
  String upcomingEventsCount(int count) {
    return 'Sắp tới $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Quá hạn $count';
  }

  @override
  String get allDay => 'Cả ngày';

  @override
  String get collapseAllDayTimeline => 'Thu gọn sự kiện cả ngày';

  @override
  String get expandAllDayTimeline => 'Mở rộng sự kiện cả ngày';

  @override
  String allDayEventsCount(int count) {
    return '$count sự kiện cả ngày';
  }

  @override
  String moreEvents(int count) {
    return '+$count sự kiện khác';
  }

  @override
  String get noMatchingEvents => 'Không có sự kiện phù hợp';

  @override
  String get noUpcomingEvents => 'Không có sự kiện sắp tới';

  @override
  String get addCalendar => 'Thêm danh mục';

  @override
  String get newCalendar => 'Danh mục mới';

  @override
  String get hideCalendar => 'Ẩn danh mục';

  @override
  String get showCalendar => 'Hiển thị danh mục';

  @override
  String get rename => 'Đổi tên';

  @override
  String get renameCalendar => 'Đổi tên danh mục';

  @override
  String get name => 'Tên';

  @override
  String get deleteCalendar => 'Xóa danh mục';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Xóa “$name”?';
  }

  @override
  String get deleteThisOccurrence => 'Xóa lần này';

  @override
  String get deleteFutureOccurrences => 'Xóa lần này và các lần sau';

  @override
  String get deleteAllOccurrences => 'Xóa toàn bộ chuỗi';

  @override
  String get duplicateEvent => 'Nhân bản';

  @override
  String get repeatsDaily => 'Lặp lại hằng ngày';

  @override
  String get repeatsMonthly => 'Lặp lại hằng tháng';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Lặp lại mỗi $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count lần';
  }

  @override
  String get recurrenceDaily => 'Hằng ngày';

  @override
  String get recurrenceMonthly => 'Hằng tháng';

  @override
  String get recurrenceCustom => 'Tùy chỉnh';

  @override
  String get recurrenceEvery => 'Mỗi';

  @override
  String get recurrenceUnit => 'Đơn vị';

  @override
  String get recurrenceDays => 'Ngày';

  @override
  String get recurrenceWeeks => 'Tuần';

  @override
  String get recurrenceMonths => 'Tháng';

  @override
  String get recurrenceRepeatCount => 'Số lần lặp';

  @override
  String get recurrenceNoLimit => 'Không giới hạn';

  @override
  String get recurrencePositiveNumber => 'Nhập một số dương';

  @override
  String get clearEndDate => 'Xóa ngày kết thúc';

  @override
  String get pickDate => 'Chọn ngày';

  @override
  String get pickTime => 'Chọn giờ';

  @override
  String get reminder => 'Lời nhắc trong ứng dụng';

  @override
  String get reminderAtStart => 'Khi bắt đầu';

  @override
  String reminderMinutesBefore(int minutes) {
    return 'Trước $minutes phút';
  }

  @override
  String get reminderHourBefore => 'Trước 1 giờ';

  @override
  String get reminderDayBefore => 'Trước 1 ngày';

  @override
  String get markReminderHandled => 'Đánh dấu đã xử lý';

  @override
  String get restoreReminder => 'Khôi phục lời nhắc trong ứng dụng';

  @override
  String get reminderHandled =>
      'Đã đánh dấu lời nhắc trong ứng dụng là đã xử lý';

  @override
  String get reminderRestored => 'Đã khôi phục lời nhắc trong ứng dụng';

  @override
  String get reminderUpcoming => 'Sắp tới';

  @override
  String get reminderOverdue => 'Quá hạn';

  @override
  String get generalFitWeekColumnsToWidth => 'Vừa tuần với màn hình';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Hiển thị cả tuần trong bố cục nhỏ gọn. Tắt để cuộn ngang. Phạm vi tùy chỉnh trên 7 ngày vẫn cuộn ngang.';

  @override
  String get showWeekends => 'Hiển thị cuối tuần';

  @override
  String get startHour => 'Giờ bắt đầu';

  @override
  String get endHour => 'Giờ kết thúc';

  @override
  String get timeGridDensity => 'Mật độ lưới thời gian';

  @override
  String get timeGridHourHeight => 'Chiều cao mỗi giờ';

  @override
  String get timeGridHourHeightHint =>
      'Điều chỉnh tỷ lệ dọc của chế độ xem ngày và tuần mà không thay đổi khoảng lưới 15, 30 hoặc 60 phút.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Nhập tệp JSON';

  @override
  String get pasteJson => 'Dán JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Nhập danh mục từ JSON đã sao chép';

  @override
  String get importIcsFile => 'Nhập tệp ICS';

  @override
  String get importIcsFileDesc => 'Đọc sự kiện từ tệp lịch .ics';

  @override
  String get pasteIcs => 'Dán ICS';

  @override
  String get pasteIcsDesc => 'Nhập sự kiện từ văn bản lịch đã sao chép';

  @override
  String get copyJson => 'Sao chép JSON';

  @override
  String get copyJsonDesc => 'Sao chép danh mục đã chọn dưới dạng văn bản JSON';

  @override
  String get shareIcs => 'Chia sẻ ICS';

  @override
  String get shareIcsDesc => 'Chia sẻ danh mục đã chọn dưới dạng .ics';

  @override
  String get saveIcs => 'Lưu ICS';

  @override
  String get saveIcsDesc => 'Lưu danh mục đã chọn dưới dạng .ics';

  @override
  String get copyIcs => 'Sao chép ICS';

  @override
  String get copyIcsDesc => 'Sao chép danh mục đã chọn dưới dạng văn bản ICS';

  @override
  String get importIcs => 'Nhập ICS';

  @override
  String get icsContent => 'Nội dung ICS';

  @override
  String get pasteIcsContentHint => 'Dán nội dung BEGIN:VCALENDAR vào đây';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Tìm thấy $count sự kiện. Thêm thành danh mục mới hay thay thế danh mục hiện có?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Đã nhập $count danh mục với $warningCount cảnh báo';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Đã bỏ qua một sự kiện thiếu giờ bắt đầu.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Đã bỏ qua một sự kiện có định dạng giờ bắt đầu không được hỗ trợ.';

  @override
  String get importWarningAdjustedEnd =>
      'Đã điều chỉnh một sự kiện có giờ kết thúc không muộn hơn giờ bắt đầu.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Các trường ICS không được hỗ trợ đã được thêm vào ghi chú: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Đã bỏ qua tần suất lặp không được hỗ trợ: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs => 'Chọn danh mục để sao chép thành ICS';

  @override
  String get selectCalendarsToExportIcs => 'Chọn danh mục để xuất thành ICS';

  @override
  String get exportIcsText => 'Xuất văn bản ICS';

  @override
  String get exportJsonText => 'Xuất văn bản JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Dữ liệu ứng dụng đã được khôi phục từ bản sao lưu trước đó vì không tải được tệp chính.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Cả tệp dữ liệu chính và bản sao lưu đều bị hỏng. Ứng dụng hiện khởi chạy với dữ liệu mới.';

  @override
  String get dataRecoveryCorruptTitle => 'Dữ liệu của bạn cần được khôi phục';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked không thể đọc tệp dữ liệu chính hoặc bản sao lưu của tệp. Các bản sao được bảo vệ đã được tạo trước khi chặn ghi dữ liệu.';

  @override
  String get dataRecoveryIoFailureTitle => 'Không thể truy cập bộ nhớ';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Hiện Sked không thể truy cập bộ nhớ cục bộ. Hãy kiểm tra quyền truy cập bộ nhớ hoặc tình trạng thiết bị rồi thử lại. Dữ liệu hiện có sẽ không bị ghi đè.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Cập nhật Sked để mở dữ liệu này';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Dữ liệu này được tạo bằng phiên bản Sked mới hơn. Hãy cập nhật ứng dụng trước khi thử lại. Để bảo vệ dữ liệu, bạn không thể bắt đầu với dữ liệu mới trong trạng thái này.';

  @override
  String get dataRecoveryRetryAction => 'Thử lại';

  @override
  String get dataRecoveryArtifactsHint =>
      'Các tệp khôi phục hoặc vị trí lưu trữ bị ảnh hưởng được liệt kê bên dưới. Hãy giữ nguyên các tệp cho đến khi khôi phục xong dữ liệu.';

  @override
  String get dataRecoveryArtifactsAction => 'Xem tệp và vị trí khôi phục';

  @override
  String get dataRecoveryStartFreshAction => 'Bắt đầu với dữ liệu mới';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Bắt đầu với dữ liệu mới?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Các bản sao được bảo vệ sẽ được giữ lại, nhưng Sked sẽ tạo tệp dữ liệu cục bộ mới. Chỉ tiếp tục nếu bạn không muốn thử khôi phục lại trước.';

  @override
  String get previousMonth => 'Tháng trước';

  @override
  String get nextMonth => 'Tháng sau';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes phút';
  }

  @override
  String get reminderInProgress => 'Đang diễn ra';

  @override
  String get deleteCourseTitle => 'Xóa môn học';

  @override
  String get deleteCourseMessage => 'Xóa môn học này?';

  @override
  String get showLunarCalendar => 'Hiển thị âm lịch';

  @override
  String monthDayEvents(int day, int count) {
    return 'Ngày $day, $count sự kiện';
  }

  @override
  String get defaultView => 'Chế độ xem mặc định';

  @override
  String get generalDefaultViewSection => 'Khi khởi động';

  @override
  String get generalViewSwitchBehavior => 'Nút chuyển chế độ xem';

  @override
  String get settingsWorkspaceMode => 'Không gian làm việc hiện tại';

  @override
  String get hideHomeWorkspaceNavigation => 'Ẩn điều hướng không gian làm việc';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Ẩn điều hướng không gian làm việc. Bạn vẫn có thể chuyển bằng menu trên màn hình chính.';

  @override
  String get generalDateLabelFormat => 'Định dạng nhãn ngày';

  @override
  String get generalDateLabelFormatLocalized =>
      'Theo ngôn ngữ (tháng 7 năm 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Dấu gạch chéo (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Bố cục thanh công cụ';

  @override
  String get toolbarNavigationSection => 'Điều hướng trên thanh công cụ';

  @override
  String get toolbarNavigationHiddenBehavior => 'Xử lý mục bị ẩn';

  @override
  String get toolbarNavigationRemove => 'Ẩn hoàn toàn';

  @override
  String get toolbarNavigationMore => 'Chuyển vào Thêm';

  @override
  String get toolbarNavigationReorder => 'Sắp xếp các mục trên thanh công cụ';

  @override
  String get toolbarNavigationVisibility => 'Hiển thị mục trên thanh công cụ';

  @override
  String get toolbarNavigationTimetable => 'Bộ chọn thời khóa biểu';

  @override
  String get toolbarNavigationWeek => 'Bộ chọn tuần';

  @override
  String get toolbarNavigationView => 'Bộ chuyển chế độ xem';

  @override
  String get toolbarNavigationCategory => 'Bộ chọn danh mục';

  @override
  String get toolbarNavigationDate => 'Bộ chọn ngày';

  @override
  String get generalToolbarWidthPolicy => 'Phân bổ không gian thanh công cụ';

  @override
  String get generalToolbarWidthContent => 'Phân bổ tự động';

  @override
  String get generalToolbarWidthBalanced => 'Cân bằng';

  @override
  String get generalToolbarWidthCalendarPriority => 'Ưu tiên danh mục';

  @override
  String get generalToolbarWidthDatePriority => 'Ưu tiên ngày';

  @override
  String get generalViewSwitchCycle => 'Luân phiên các chế độ xem';

  @override
  String get generalViewSwitchMenu => 'Mở trình đơn chế độ xem';

  @override
  String get generalViewSwitchTooltip => 'Chuyển chế độ xem';

  @override
  String get generalViewSwitchMenuTooltip => 'Chọn chế độ xem';

  @override
  String get generalViewLongPressTodayHint => 'Nhấn giữ để về hôm nay';

  @override
  String get generalScheduleDisplaySection => 'Hiển thị lịch';

  @override
  String get generalTimeGridSection => 'Lưới thời gian';

  @override
  String get generalPopupSection => 'Hành vi cửa sổ bật lên';

  @override
  String get quickActionsSection => 'Thao tác nhanh';

  @override
  String get showAddCourseFab => 'Hiển thị nút nổi thêm môn học';

  @override
  String get showAddCourseFabHint =>
      'Hiển thị hoặc ẩn nút nổi thêm môn học ở góc dưới bên phải thời khóa biểu.';

  @override
  String get showAddEventFab => 'Hiển thị nút nổi thêm sự kiện';

  @override
  String get showAddEventFabHint =>
      'Hiển thị hoặc ẩn nút nổi thêm sự kiện ở góc dưới bên phải lịch.';

  @override
  String get enableLongPressAddCourse => 'Nhấn giữ ô trống để thêm môn học';

  @override
  String get enableLongPressAddCourseHint =>
      'Nhấn giữ vùng trống trong lưới thời khóa biểu để thêm môn học.';

  @override
  String get enableLongPressAddEvent => 'Nhấn giữ ô trống để thêm sự kiện';

  @override
  String get enableLongPressAddEventHint =>
      'Trong chế độ xem ngày hoặc tuần, nhấn giữ vùng trống trên lưới thời gian để thêm sự kiện.';

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
  String get developerNotificationDiagnostics => 'Chẩn đoán thông báo';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Kiểm tra trạng thái gửi trên Android, tạo lại kế hoạch lời nhắc hiện có và gửi thông báo thử nghiệm an toàn qua dịch vụ thông báo thông thường của Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Chẩn đoán thông báo chỉ khả dụng trên Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Chẩn đoán thông báo sẽ khả dụng khi bộ điều phối lịch khởi động.';

  @override
  String get developerNotificationRefresh => 'Làm mới chẩn đoán';

  @override
  String get developerNotificationSystemStatus => 'Quyền thông báo hệ thống';

  @override
  String get developerNotificationPermissionAllowed => 'Đã cho phép';

  @override
  String get developerNotificationPermissionBlocked => 'Đã chặn';

  @override
  String get developerNotificationExactAlarm => 'Báo thức chính xác';

  @override
  String get developerNotificationExactAlarmAllowed => 'Đã cho phép';

  @override
  String get developerNotificationExactAlarmBlocked => 'Chưa cho phép';

  @override
  String get developerNotificationPlan => 'Kế hoạch thông báo lịch';

  @override
  String get developerNotificationCoverage => 'Phạm vi bao phủ lời nhắc';

  @override
  String get developerNotificationCoverageReady =>
      'Tất cả lời nhắc đã biết có điểm kết thúc đã được lên lịch trực tiếp';

  @override
  String get developerNotificationCoverageRenewable =>
      'Lời nhắc lặp lại được gia hạn dài hạn theo khả năng của hệ thống';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Đã đầy số lượng báo thức trực tiếp; lời nhắc sau đó được gia hạn theo khả năng của hệ thống';

  @override
  String get developerNotificationCoverageBlocked =>
      'Chưa đáp ứng điều kiện gửi đúng giờ';

  @override
  String get developerNotificationCoverageFailed =>
      'Lần đồng bộ lời nhắc gần nhất thất bại';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled báo thức trực tiếp / giới hạn $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return 'Đã lên lịch $scheduled, dự kiến $planned';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Lỗi gần nhất: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Tạo lại kế hoạch thông báo';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Đã tạo lại kế hoạch thông báo.';

  @override
  String get developerNotificationTestChannel => 'Kênh thử nghiệm';

  @override
  String get developerNotificationTestCourse => 'Lời nhắc môn học';

  @override
  String get developerNotificationTestSchedule => 'Lời nhắc sự kiện';

  @override
  String get developerNotificationImmediateTest => 'Gửi thử ngay';

  @override
  String get developerNotificationThirtySecondTest =>
      'Lên lịch thử nền sau 30 giây';

  @override
  String get developerNotificationImmediateQueued =>
      'Đã gửi thông báo thử nghiệm tức thì.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Đã lên lịch thử nghiệm nền sau 30 giây.';

  @override
  String get developerNotificationAppSwitch => 'Công tắc lời nhắc của ứng dụng';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Đã bật lời nhắc thông thường';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Đã tắt lời nhắc thông thường; vẫn có thể chạy thử nghiệm dành cho nhà phát triển';

  @override
  String get developerNotificationTimeZone => 'Múi giờ địa phương';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Chưa được tạo. Chạy thử nghiệm dành cho nhà phát triển sẽ tạo kênh này.';

  @override
  String get developerNotificationChannelEnabledState => 'Đã bật';

  @override
  String get developerNotificationChannelBlockedState => 'Đã chặn';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Mức độ quan trọng: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Không có thông tin mức độ quan trọng';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending đang chờ / $active đang hiển thị';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Hệ thống hiển thị gần nhất lúc $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Chưa ghi nhận lần tính lại nào.';

  @override
  String get developerNotificationNextReminder => 'Lời nhắc thực tế tiếp theo';

  @override
  String get developerNotificationNoPendingReminder =>
      'Không có lời nhắc trong tương lai trong kế hoạch hiện tại';

  @override
  String get developerNotificationNextMaintenance => 'Lần bảo trì tiếp theo';

  @override
  String get developerNotificationNextRenewal =>
      'Lần gia hạn theo khả năng tiếp theo';

  @override
  String get developerNotificationNoMaintenance => 'Chưa lên lịch';

  @override
  String get developerNotificationTruncation => 'Cắt bớt kế hoạch';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count mục bị bỏ qua do giới hạn kế hoạch';
  }

  @override
  String get developerNotificationLastReconciliation => 'Lần tính lại gần nhất';

  @override
  String get developerNotificationLastSynchronization =>
      'Lần đồng bộ lời nhắc gần nhất';

  @override
  String get developerNotificationLateRecovery => 'Khôi phục lời nhắc trễ';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count lời nhắc đã được khôi phục sau thời điểm ban đầu';
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
  String get developerNotificationReconcileOriginForeground => 'Tiền cảnh';

  @override
  String get developerNotificationReconcileOriginBackground => 'Nền';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Tính lại toàn bộ';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Bảo trì';

  @override
  String get developerNotificationReconcileModeRecovery => 'Khôi phục';

  @override
  String get developerNotificationRunRecovery => 'Chạy khôi phục lời nhắc';

  @override
  String get developerNotificationRecoveryComplete =>
      'Đã khôi phục xong lời nhắc';

  @override
  String get developerNotificationReconcileResultSuccess => 'Thành công';

  @override
  String get developerNotificationReconcileResultSkipped => 'Đã bỏ qua';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Bị chặn cho đến khi đáp ứng đủ điều kiện gửi đúng giờ';

  @override
  String get developerNotificationReconcileResultFailed => 'Thất bại';

  @override
  String get developerNotificationBackgroundLimits =>
      'Giới hạn chạy nền của nhà sản xuất';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Giới hạn chạy nền của nhà sản xuất có thể ảnh hưởng đến việc gửi.';

  @override
  String get developerNotificationAutostart => 'Khởi động nền của nhà sản xuất';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Nhà sản xuất $vendor; có lối vào trang cài đặt của nhà sản xuất. Android không thể cung cấp trạng thái cấp quyền này.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Nhà sản xuất $vendor; sử dụng trang thông tin ứng dụng thay thế. Android không thể cung cấp trạng thái cấp quyền này.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Không có lối vào trang cài đặt chạy nền của nhà sản xuất.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Đích mở gần nhất: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'cài đặt của nhà sản xuất';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'thông tin ứng dụng';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'không có';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Điều kiện khôi phục sau khi khởi động lại';

  @override
  String get developerNotificationRebootBoundary =>
      'Khôi phục bắt đầu sau lần mở khóa đầu tiên; ứng dụng bị buộc dừng không thể tự khởi động.';

  @override
  String get developerNotificationTestChecking =>
      'Không thể thử nghiệm trong khi đang kiểm tra trạng thái thông báo.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Không thể thử nghiệm vì thông báo hệ thống bị chặn.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Không thể thử nghiệm vì kênh thông báo đã chọn bị chặn.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Do cài đặt thông báo Windows quản lý';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Không áp dụng trên Windows';

  @override
  String get developerNotificationWindowsIdentity => 'Danh tính gói Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Có danh tính MSIX; có thể hủy thông báo đang hiển thị';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Cài đặt bản MSIX để hủy thông báo đang hiển thị một cách đáng tin cậy';

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

  @override
  String get notificationSettingsSection => 'Lời nhắc và thông báo';

  @override
  String get notificationCoverage => 'Phạm vi bao phủ lời nhắc';

  @override
  String get notificationCoverageRenewable =>
      'Sự kiện lặp lại không có ngày kết thúc dùng cơ chế gia hạn nền để duy trì lời nhắc lâu dài.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android có thể lên lịch trực tiếp tối đa $capacity lời nhắc; hệ thống sẽ cố gắng gia hạn trước các lời nhắc về sau.';
  }

  @override
  String get notificationSettingsEnabled => 'Bật lời nhắc và thông báo';

  @override
  String get notificationSettingsEnabledHint =>
      'Chỉ lên lịch cho các mục có lời nhắc. Đặt lời nhắc mặc định bên dưới cho các môn học dùng cài đặt mặc định.';

  @override
  String get notificationPrecisionLimitations =>
      'Lời nhắc phụ thuộc vào quyền hệ thống và hoạt động nền. Tắt máy, đổi giờ hoặc giới hạn hệ thống có thể gây chậm trễ.';

  @override
  String get notificationSettingsEnabledSummary => 'Đã bật';

  @override
  String get notificationSettingsDisabledSummary => 'Đã tắt';

  @override
  String get notificationDefaultsSection => 'Lời nhắc mặc định';

  @override
  String get notificationCourseDefaultReminder =>
      'Lời nhắc mặc định cho môn học';

  @override
  String get notificationGeneralDefaultReminder =>
      'Lời nhắc mặc định cho sự kiện';

  @override
  String get notificationReminderOff => 'Không nhắc';

  @override
  String notificationReminderCustom(int minutes) {
    return 'Trước $minutes phút';
  }

  @override
  String get notificationPermission => 'Quyền thông báo';

  @override
  String get notificationPermissionGranted => 'Hệ thống đã cho phép';

  @override
  String get notificationPermissionDenied => 'Hệ thống đã chặn';

  @override
  String get notificationPermissionChecking => 'Đang kiểm tra quyền…';

  @override
  String get notificationPermissionRequest => 'Yêu cầu quyền';

  @override
  String get notificationPermissionOpenSettings => 'Mở cài đặt hệ thống';

  @override
  String get notificationPermissionRequestFailed =>
      'Không thể đọc quyền thông báo. Hãy thử lại.';

  @override
  String get notificationExactAlarm => 'Quyền báo thức chính xác';

  @override
  String get notificationExactAlarmAllowed => 'Hệ thống đã cho phép';

  @override
  String get notificationExactAlarmRequired => 'Cần thiết để nhắc đúng giờ';

  @override
  String get notificationExactAlarmRequest => 'Cho phép báo thức chính xác';

  @override
  String get notificationBatteryOptimization => 'Tối ưu hóa pin';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Đã được miễn tối ưu hóa pin trên Android';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Lời nhắc chính xác cần được miễn tối ưu hóa pin trên Android';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Mở cài đặt tối ưu hóa pin';

  @override
  String get notificationAutostart => 'Khởi động nền của nhà sản xuất';

  @override
  String get notificationAutostartVendorHint =>
      'Cho phép tự khởi động hoặc chạy nền để khôi phục lời nhắc sau khi khởi động lại.';

  @override
  String get notificationAutostartFallbackHint =>
      'Mở trang thông tin ứng dụng Sked và cho phép chạy nền. Android không thể xác minh cài đặt này của nhà sản xuất.';

  @override
  String get notificationAutostartUnavailable =>
      'Không tìm thấy trang cài đặt của nhà sản xuất. Hãy kiểm tra thông tin ứng dụng Sked thủ công.';

  @override
  String get notificationAutostartRequest =>
      'Mở cài đặt chạy nền của nhà sản xuất';

  @override
  String get notificationAutostartOpenFailed =>
      'Không thể mở cài đặt chạy nền của nhà sản xuất. Hãy kiểm tra thông tin ứng dụng Sked thủ công.';

  @override
  String get notificationLockScreenTitles =>
      'Hiển thị tiêu đề trên màn hình khóa';

  @override
  String get notificationLockScreenTitlesHint =>
      'Khi tắt, chi tiết thông báo sẽ được ẩn trên màn hình khóa.';

  @override
  String get notificationWidgets => 'Tiện ích màn hình chính';

  @override
  String get notificationWidgetsDesc =>
      'Làm mới tiện ích Sked và xem cách thêm tiện ích từ trình khởi chạy.';

  @override
  String get notificationWidgetsDialogTitle => 'Thêm tiện ích Sked';

  @override
  String get notificationWidgetsDialogMessage =>
      'Trên màn hình chính của thiết bị, nhấn giữ một vùng trống, chọn Tiện ích rồi thêm tiện ích Sked. Tiện ích hiển thị các môn học hoặc sự kiện sắp tới.';

  @override
  String get notificationWidgetsRefresh => 'Làm mới tiện ích';

  @override
  String get notificationWidgetsRefreshed => 'Đã làm mới tiện ích';

  @override
  String get notificationPlatformUnsupported =>
      'Nền tảng này không cung cấp thông báo gốc.';

  @override
  String get workspaceFeatures => 'Quản lý tính năng';

  @override
  String get workspaceBoth => 'Thời khóa biểu và lịch';

  @override
  String get workspaceOnlyStudent => 'Chỉ thời khóa biểu';

  @override
  String get workspaceOnlyGeneral => 'Chỉ lịch';

  @override
  String get workspaceDisableTitle => 'Tắt không gian làm việc này?';

  @override
  String get workspaceDisableMessage =>
      'Dữ liệu và tùy chọn sẽ được giữ lại. Các tính năng và lời nhắc sẽ dừng cho đến khi bạn bật lại tại đây.';

  @override
  String get workspaceEnableHint =>
      'Chọn các tính năng bạn sử dụng. Phải bật ít nhất một tính năng.';

  @override
  String get workspaceLastRequired =>
      'Phải bật ít nhất một không gian làm việc.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Không gian làm việc đã tắt nhưng chưa thể xóa lời nhắc. Hãy thử khôi phục thông báo lại.';

  @override
  String get settingsSearch => 'Tìm kiếm cài đặt';

  @override
  String get settingsNoResults => 'Không có cài đặt phù hợp';

  @override
  String get settingsDataPrivacy => 'Dữ liệu và quyền riêng tư';

  @override
  String get workspacePreferences => 'Hiển thị và tương tác';

  @override
  String get workspaceManage => 'Quản lý';

  @override
  String get selectedDayAgenda => 'Ngày đã chọn';

  @override
  String get notificationTroubleshooting => 'Quyền và khắc phục sự cố';

  @override
  String get settingsConnection => 'Kết nối';

  @override
  String get settingsAdvanced => 'Nâng cao';

  @override
  String get unsavedChangesMessage =>
      'Bạn có thay đổi chưa lưu. Hủy thay đổi và thoát?';

  @override
  String get backupWorkspaceSelection =>
      'Bản sao lưu đầy đủ bao gồm dữ liệu và lựa chọn không gian làm việc được bật.';

  @override
  String get assistantLayoutPreview => 'AI · Xem trước bố cục';

  @override
  String get assistantSelectionContext => 'Dùng mục đang chọn làm ngữ cảnh';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Bản nháp tin nhắn';

  @override
  String get assistantPreviewNoSend =>
      'Chỉ xem trước bố cục. Không gửi hoặc thay đổi bất cứ nội dung nào.';

  @override
  String get resizePanel => 'Đổi kích thước bảng';

  @override
  String get minimizeWindow => 'Thu nhỏ';

  @override
  String get maximizeWindow => 'Phóng to';

  @override
  String get restoreWindow => 'Khôi phục cửa sổ';

  @override
  String get closeWindow => 'Đóng cửa sổ';

  @override
  String get courseSystemReminder => 'Lời nhắc hệ thống';

  @override
  String courseReminderInherit(String reminder) {
    return 'Dùng mặc định ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Lời nhắc hệ thống đang tắt trong cài đặt thông báo. Bạn vẫn có thể lưu tùy chọn lời nhắc cho môn học này.';

  @override
  String get courseReminderDefaultOff =>
      'Chưa đặt lời nhắc mặc định cho môn học. Chọn lời nhắc tùy chỉnh tại đây hoặc đặt mặc định trong cài đặt thông báo.';

  @override
  String get courseReminderDeliveryHint =>
      'Tùy chọn này được lưu cùng môn học. Việc gửi phụ thuộc vào quyền thông báo hệ thống và giới hạn chạy nền.';

  @override
  String get courseReminderPermissionUnknown =>
      'Chưa kiểm tra trạng thái thông báo hệ thống. Hãy kiểm tra cài đặt thông báo trước khi dựa vào lời nhắc.';

  @override
  String get courseReminderMinutesLabel => 'Số phút trước giờ học';

  @override
  String get exportAction => 'Xuất';

  @override
  String get datePickerSelectWeek => 'Chọn tuần';

  @override
  String get datePickerSelectMonth => 'Chọn tháng';

  @override
  String get generalDateLabelFormatDescription =>
      'Áp dụng cho điều hướng ngày trên máy tính và màn hình nhỏ.';

  @override
  String get dateRangeTitle => 'Chọn khoảng ngày';

  @override
  String get dateRangeCustom => 'Tùy chỉnh';

  @override
  String get dateRangeChooseStart => 'Chọn ngày bắt đầu';

  @override
  String get dateRangeChooseEnd => 'Chọn ngày kết thúc';

  @override
  String get dateRangeLimit =>
      'Chọn từ 1 đến 14 ngày, bao gồm cả hai ngày đầu và cuối.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ngày',
      one: '1 ngày',
    );
    return 'Tùy chỉnh · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Chọn bằng bánh xe cuộn';

  @override
  String get courseReminderUseDefault => 'Dùng mặc định';

  @override
  String get courseReminderInvalidMinutes =>
      'Nhập số phút là số nguyên lớn hơn hoặc bằng không.';

  @override
  String get generalCustomColumnWidth =>
      'Chiều rộng cột của chế độ xem tùy chỉnh';

  @override
  String get generalCustomColumnWidthAuto => 'Tự động';

  @override
  String get generalCustomColumnWidthManual => 'Chiều rộng tối thiểu';

  @override
  String get generalCustomColumnWidthMinimum => 'Chiều rộng tối thiểu mỗi ngày';

  @override
  String get generalCustomColumnWidthHint =>
      'Tất cả ngày dùng cùng chiều rộng tối thiểu. Các cột lấp đầy không gian sẵn có hoặc cuộn ngang. Chỉ ảnh hưởng đến chế độ xem tùy chỉnh.';

  @override
  String get settingsAppearanceLanguage => 'Giao diện và ngôn ngữ';

  @override
  String get settingsAppearanceDetails => 'Màu sắc và đường viền';

  @override
  String get monthNoEvents => 'Không có sự kiện trong ngày này';

  @override
  String get settingsOverview => 'Tổng quan';

  @override
  String get settingsThemeTarget => 'Giao diện cho';

  @override
  String get settingsColorMode => 'Chế độ màu';

  @override
  String get settingsNotificationPreferences => 'Tùy chọn lời nhắc';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Lời nhắc mặc định, quyền và độ tin cậy';

  @override
  String get settingsFeaturesSummary => 'Không gian làm việc và điều hướng';

  @override
  String get settingsPrivacySummary =>
      'Chính sách riêng tư và xóa dữ liệu cục bộ';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tiết',
      one: '1 tiết',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Tiết';

  @override
  String get periodTimesDurationColumn => 'Thời lượng';

  @override
  String get periodTimesGapColumn => 'Giờ nghỉ';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes phút';
  }

  @override
  String get periodTimesSavePending => 'Đang chờ lưu…';

  @override
  String get periodTimesSaveFailed => 'Chưa lưu · Lưu thất bại';

  @override
  String get periodTimesInvalidStatus =>
      'Chưa lưu · Hãy sửa các giờ được đánh dấu';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked không thể xác nhận lần lưu gần nhất đã được hoàn tác hay chưa. Việc ghi đã tạm dừng và các bản sao khôi phục được giữ lại. Hãy kiểm tra bộ nhớ rồi thử tải lại.';

  @override
  String get settingsPanelDisplayMode => 'Cách hiển thị bảng';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Dùng chung cho thời khóa biểu và lịch';

  @override
  String get settingsPanelDisplayOverlay => 'Lớp phủ';

  @override
  String get settingsPanelDisplaySideBySide => 'Song song';

  @override
  String get settingsPanelDisplayAutomatic => 'Tự động';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Phủ bên phải mà không đổi kích thước lịch.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Ưu tiên hiển thị song song; chỉ dùng lớp phủ khi lịch quá hẹp.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Hiển thị song song khi lịch còn đủ rộng để đọc; nếu không thì dùng lớp phủ.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Tắt hiển thị Cài đặt hoặc Không gian làm việc trên thanh công cụ sẽ chuyển mục đó vào Thêm, vẫn giữ lối truy cập. Không thể ẩn Thêm khi trình đơn còn chứa thao tác thiết yếu. Chuyển không gian làm việc chỉ xuất hiện khi thanh điều hướng dưới bị ẩn và có nhiều không gian làm việc được bật.';

  @override
  String get reminderEnded => 'Đã kết thúc';

  @override
  String get reminderAutoCloseHint =>
      'Đóng sau 10 giây. Tương tác để giữ bảng mở.';

  @override
  String get showReminderIndependently => 'Mở riêng';

  @override
  String get categoryManagerTitle => 'Quản lý danh mục';

  @override
  String get categoryHidden => 'Đã ẩn';

  @override
  String get categoryShowOnCalendar => 'Hiển thị trên lịch';

  @override
  String get categoryHideOnCalendar => 'Ẩn khỏi lịch';

  @override
  String get categoryEditColor => 'Đổi màu danh mục';

  @override
  String get categoryThemePalette => 'Bảng màu giao diện';

  @override
  String get categoryCustomColor => 'Tùy chỉnh';

  @override
  String get colorHexInvalid => 'Nhập mã màu thập lục phân gồm sáu ký tự.';

  @override
  String categoryColorSlot(int number) {
    return 'Màu giao diện $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Bản cập nhật trên cửa hàng có thể đến muộn hơn. Kiểm tra tính khả dụng trên trang cửa hàng.';

  @override
  String get storePrereleaseNotice =>
      'Nhận thông báo bản phát hành thử không tự động đăng ký bạn vào kênh thử nghiệm của cửa hàng.';

  @override
  String get updateFoundTitle => 'Có phiên bản mới';

  @override
  String get updateNoNotes => 'Không có ghi chú phát hành.';

  @override
  String get updateLater => 'Để sau';

  @override
  String get updateRetry => 'Thử lại';

  @override
  String get updatePrerelease => 'Bản phát hành thử';

  @override
  String get updateNetworkFailure =>
      'Không thể kiểm tra cập nhật. Hãy kiểm tra kết nối và thử lại.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Không tìm thấy phiên bản mới hơn (hiện tại: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Đang khôi phục bản sao lưu…';

  @override
  String get backupRestoreInProgressMessage =>
      'Bạn có thể thay đổi dữ liệu và cài đặt sau khi khôi phục xong. Bạn vẫn có thể xem nội dung.';
}
