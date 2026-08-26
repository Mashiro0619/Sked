// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return '$week주차';
  }

  @override
  String get addCourse => '수업 추가';

  @override
  String get settings => '설정';

  @override
  String get multiTimetableSwitch => '시간표 전환';

  @override
  String currentTimetableWeeks(int weeks) {
    return '현재 시간표 · $weeks주';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return '탭하여 전환 · $weeks주';
  }

  @override
  String get editTimetable => '시간표 수정';

  @override
  String get schoolImportResultEditorTitle => '분석 결과 편집';

  @override
  String get createTimetable => '새 시간표';

  @override
  String get jumpToWeek => '주차로 이동';

  @override
  String get timetable => '시간표';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => '시간표 이름';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => '전체 주차';

  @override
  String get delete => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get deleteTimetableTitle => '시간표 삭제';

  @override
  String deleteTimetableMessage(Object name) {
    return '\"$name\"을(를) 삭제할까요?';
  }

  @override
  String get noTimetableTitle => '아직 시간표가 없습니다';

  @override
  String get noTimetableMessage => '시간표를 만들거나 JSON 파일에서 가져오세요.';

  @override
  String get importTimetable => '시간표 가져오기';

  @override
  String get courseName => '수업 이름';

  @override
  String get location => '장소';

  @override
  String get dayOfWeek => '요일';

  @override
  String get semesterWeeks => '주차';

  @override
  String get startTime => '시작 시간';

  @override
  String get endTime => '종료 시간';

  @override
  String get linkedPeriods => '연결된 교시';

  @override
  String get linkedPeriodsUnmatched => '현재 시간과 일치하는 교시가 없습니다. 탭해서 직접 선택하세요.';

  @override
  String periodRangeLabel(int start, int end) {
    return '$start-$end교시';
  }

  @override
  String get teacherName => '교수명';

  @override
  String get credits => '학점';

  @override
  String get remarks => '비고';

  @override
  String get customFields => '사용자 지정 필드';

  @override
  String get customFieldsHint => '한 줄에 하나씩, 형식: key:value';

  @override
  String get more => '더보기';

  @override
  String get selectDayOfWeek => '요일 선택';

  @override
  String get selectSemesterWeeks => '주차 선택';

  @override
  String get selectAll => '전체 선택';

  @override
  String get clear => '지우기';

  @override
  String get confirm => '확인';

  @override
  String get selectLinkedPeriods => '연결된 교시 선택';

  @override
  String get addCourseTitle => '수업 추가';

  @override
  String get editCourseTitle => '수업 수정';

  @override
  String get editCourseTooltip => '수업 수정';

  @override
  String get place => '장소';

  @override
  String get time => '시간';

  @override
  String get notFilled => '입력되지 않음';

  @override
  String get none => '없음';

  @override
  String get conflictCourses => '충돌하는 수업';

  @override
  String get locationNotFilled => '장소가 입력되지 않음';

  @override
  String get setAsDisplayed => '표시 대상으로 설정';

  @override
  String get editThisCourse => '이 수업 수정';

  @override
  String get settingsTitle => '설정';

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
  String get noTimetableSettings => '설정할 수 있는 시간표가 현재 없습니다.';

  @override
  String get semesterStartDate => '학기 시작일';

  @override
  String get periodTimeSets => '교시 시간 세트';

  @override
  String get noPeriodTimeAvailable => '사용 가능한 교시 시간 세트가 없습니다';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count교시';
  }

  @override
  String get coursePopupDismissSetting => '바깥쪽을 탭해 수업 팝업 닫기 허용';

  @override
  String get coursePopupDismissSettingHint =>
      '이 옵션을 끄면 아래로 스와이프하여 닫는 동작도 비활성화됩니다.';

  @override
  String get preserveTimetableGaps => '시간표 빈칸 유지';

  @override
  String get preserveTimetableGapsHint =>
      '끄면 점심시간과 쉬는 시간 공백이 줄어들어 뒤 수업이 위로 이동합니다.';

  @override
  String get showPastEndedCourses => '이미 종료된 수업 표시';

  @override
  String get showPastEndedCoursesHint =>
      '실제 현재 주차 기준으로 이미 끝난 수업을 더 연한 회색으로 표시합니다.';

  @override
  String get showFutureCourses => '향후 수업 표시';

  @override
  String get showFutureCoursesHint =>
      '이번 주에는 진행되지 않지만 이후 주차에 나타나는 수업을 회색으로 표시합니다.';

  @override
  String get timetableDisplaySettings => '시간표 표시 및 상호작용';

  @override
  String get timetableDisplaySettingsDesc => '수업 표시, 레이아웃, 주 전환 제스처 및 빠른 추가';

  @override
  String get showTimetableGridLines => '시간표 격자선 표시';

  @override
  String get showTimetableGridLinesHint => '시간표에서 가로 및 세로 격자선을 표시할지 설정합니다.';

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
  String get liveCourseOutlineColor => '수업 윤곽선 색상';

  @override
  String get liveCourseOutlineColorHint =>
      '윤곽선을 현재/다음 수업에 적용할지, 현재 페이지에 표시된 모든 수업에 적용할지 선택하세요.';

  @override
  String get liveCourseOutlineSettings => '수업 윤곽선';

  @override
  String get liveCourseOutlineSettingsHint =>
      '윤곽선 사용 여부, 적용 대상, 테마 색상 추종 여부, 실제 윤곽선 색상을 설정합니다.';

  @override
  String get liveCourseOutlineEnabled => '윤곽선 사용';

  @override
  String get liveCourseOutlineFollowTheme => '테마 색상 따르기';

  @override
  String get liveCourseOutlineTarget => '윤곽선 대상';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => '현재/다음 수업';

  @override
  String get liveCourseOutlineTargetAllDisplayed => '표시된 모든 수업';

  @override
  String get liveCourseOutlineEffectiveColor => '적용 색상';

  @override
  String get liveCourseOutlineCustomColor => '사용자 지정 윤곽선 색상';

  @override
  String get liveCourseOutlineWidth => '윤곽선 두께';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => '언어';

  @override
  String get languagePageDescription => '앱에서 실제로 사용할 수 있는 언어 중 하나를 선택하세요.';

  @override
  String get languageChinese => '중국어';

  @override
  String get languageEnglish => '영어';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API 응답';

  @override
  String get theme => '테마';

  @override
  String get themeFollowSystem => '시스템 설정 따르기';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get themeColor => '테마 색상';

  @override
  String get themeColorModeSingle => '단일 테마 색상';

  @override
  String get themeColorModeColorful => '컬러풀';

  @override
  String get themeColorUiColors => 'UI 색상';

  @override
  String get themeColorCourseColors => '수업 색상';

  @override
  String get themeColorPrimary => '기본';

  @override
  String get themeColorSecondary => '보조';

  @override
  String get themeColorTertiary => '강조';

  @override
  String get themeColorCourseText => '수업 텍스트';

  @override
  String get themeColorCourseTextAuto => '자동';

  @override
  String get themeColorCourseTextCustom => '사용자 지정 색상';

  @override
  String get themeColorCourseColorsEmpty => '시간표를 가져오면 수업 색상이 생성됩니다.';

  @override
  String get themeCustomColor => '사용자 지정 색상';

  @override
  String get themeApplyCustomColor => '색상 적용';

  @override
  String get themeApplySettings => '설정 적용';

  @override
  String get dataImportExport => '데이터 가져오기 및 내보내기';

  @override
  String get dataImportExportDesc =>
      '전체 데이터 또는 개별 시간표를 가져오거나, 현재/전체 시간표를 내보낼 수 있습니다.';

  @override
  String get appBackupTitle => '앱 백업 및 복원';

  @override
  String get appBackupSubtitle =>
      '시간표, 일정, 설정, 학교 사이트를 백업하거나 복원합니다. API 키는 포함되지 않습니다.';

  @override
  String get appBackupSheetSubtitle =>
      '전체 복원은 현재 앱 데이터를 대체합니다. AI API 키는 보안 저장소에 보관되며 백업 파일에 기록되지 않습니다.';

  @override
  String get restoreBackupFileTitle => 'JSON 파일에서 복원';

  @override
  String get restoreBackupFileSubtitle => '전체 Sked 백업 파일을 선택합니다. 복원 전에 확인합니다.';

  @override
  String get restoreBackupTextTitle => '백업 JSON 붙여넣기';

  @override
  String get restoreBackupTextSubtitle => '전체 백업을 붙여넣어 현재 앱 데이터를 복원합니다.';

  @override
  String get shareBackupTitle => '백업 파일 공유';

  @override
  String get shareBackupSubtitle => '전체 앱 데이터를 JSON으로 내보냅니다. API 키는 제외됩니다.';

  @override
  String get saveBackupTitle => '백업 파일 저장';

  @override
  String get saveBackupSubtitle => '전체 앱 백업을 로컬 파일에 저장합니다.';

  @override
  String get copyBackupTitle => '백업 텍스트 복사';

  @override
  String get copyBackupSubtitle => '전체 백업 JSON을 표시하여 복사하거나 임시로 저장할 수 있습니다.';

  @override
  String get restoreBackupConfirmTitle => '전체 백업을 복원할까요?';

  @override
  String get restoreBackupConfirmMessage =>
      '현재 모든 시간표, 일반 일정, 설정, 학교 사이트가 대체됩니다. API 키는 백업에서 가져오지 않으므로 시간표를 다시 파싱하기 전에 키를 다시 입력하세요.';

  @override
  String get restoreBackupConfirmAction => '백업 복원';

  @override
  String get restoreBackupSuccessMessage =>
      '전체 앱 백업이 복원되었습니다. AI API 키를 다시 입력해야 합니다.';

  @override
  String get restoreBackupFailureMessage => '복원에 실패했습니다. 백업 내용을 확인하고 다시 시도하세요.';

  @override
  String get openSourceLicenses => '오픈소스 라이선스';

  @override
  String get openSourceLicensesDesc =>
      'Flutter 의존성과 포함된 앱 아이콘 리소스의 라이선스를 확인합니다.';

  @override
  String get checkForUpdates => '업데이트 확인';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return '이미 최신 버전입니다 ($version)';
  }

  @override
  String get currentVersionLabel => '현재 버전';

  @override
  String get newVersionAvailable => '업데이트 उपलब्ध';

  @override
  String get latestVersionLabel => '최신 버전';

  @override
  String get updateContentLabel => '업데이트 내용';

  @override
  String get officialWebsite => '공식 웹사이트';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => '클라우드 드라이브';

  @override
  String get ignoreThisVersion => '이 버전 무시';

  @override
  String get openUpdatesFailed => '업데이트 링크를 열 수 없습니다';

  @override
  String get updateCheckFailedTitle => '업데이트 확인 실패';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'GitHub 저장소';

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
  String get openGithubFailed => 'GitHub 저장소 링크를 열 수 없습니다';

  @override
  String get openPrivacyPolicyFailed => '개인정보 처리방침 링크를 열 수 없습니다';

  @override
  String get selectPeriodTimeSet => '교시 시간 세트 선택';

  @override
  String get newItem => '새로 만들기';

  @override
  String get editPeriodTimeSet => '교시 시간 세트 수정';

  @override
  String get importTimetableFiles => '시간표 가져오기';

  @override
  String get importTimetableFilesDesc => '하나 또는 여러 개의 시간표 파일을 지원합니다.';

  @override
  String get importTimetableText => '텍스트에서 시간표 가져오기';

  @override
  String get importTimetableTextDesc => '시간표 JSON 내용을 붙여넣어 가져옵니다.';

  @override
  String get shareTimetableFiles => '시간표 파일 공유';

  @override
  String get shareTimetableFilesDesc => '먼저 하나 이상의 시간표를 선택하세요.';

  @override
  String get saveTimetableFiles => '시간표 파일 저장';

  @override
  String get saveTimetableFilesDesc => '먼저 하나 이상의 시간표를 선택하세요.';

  @override
  String get exportTimetableText => '시간표를 텍스트로 내보내기';

  @override
  String get exportTimetableTextDesc => '하나 이상의 시간표를 선택한 뒤 JSON 내용을 복사하세요.';

  @override
  String get jsonContent => 'JSON 내용';

  @override
  String get pasteJsonContentHint => '가져올 JSON 내용을 붙여넣으세요.';

  @override
  String get jsonContentEmpty => '먼저 JSON 내용을 붙여넣으세요.';

  @override
  String get copyText => '복사';

  @override
  String get copiedToClipboard => '클립보드에 복사됨';

  @override
  String get share => '공유';

  @override
  String get selectTimetablesToExport => '내보낼 시간표 선택';

  @override
  String get selectTimetablesToImport => '가져올 시간표 선택';

  @override
  String timetableCourseCount(int count) {
    return '수업 $count개';
  }

  @override
  String get importAction => '가져오기';

  @override
  String get importTimetableDialogTitle => '시간표 가져오기';

  @override
  String get chooseImportMethod => '가져오기 방식을 선택하세요.';

  @override
  String get importAsNewTimetable => '새 시간표로 가져오기';

  @override
  String get replaceCurrentTimetable => '현재 시간표 교체';

  @override
  String get importPeriodTimeSetDialogTitle => '교시 시간 세트 가져오기';

  @override
  String get importPeriodTimeSetDialogBody =>
      '이 파일에는 묶음 교시 시간 세트가 포함되어 있습니다. 가져와서 연결하시겠습니까?';

  @override
  String get importBundledPeriodTimeSets => '가져와서 연결';

  @override
  String get discardBundledPeriodTimeSets => '묶음 세트 버리기';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      '기존 교시 시간 세트가 없어 묶음 교시 시간 세트를 버릴 수 없습니다.';

  @override
  String savedToPath(Object path) {
    return '$path에 저장됨';
  }

  @override
  String get saveCancelled => '저장 취소됨';

  @override
  String get fileSaveRestrictedTitle => '파일 저장 제한됨';

  @override
  String get fileSaveRestrictedRetryMessage =>
      '시스템이 파일을 저장하지 못했습니다. 다시 시도하거나 대신 공유를 사용하세요.';

  @override
  String get retrySave => '다시 저장';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      '시스템 설정에서 파일 접근을 활성화한 뒤 돌아와 다시 내보내세요.';

  @override
  String get openSettings => '설정 열기';

  @override
  String get browserDownloadRestrictedTitle => '브라우저 다운로드 제한됨';

  @override
  String get browserDownloadRestrictedMessage =>
      '이 브라우저는 로컬 파일로 직접 저장을 지원하지 않습니다. 브라우저 다운로드 권한을 확인하거나 대신 파일 공유를 사용하세요.';

  @override
  String get switchToShare => '대신 공유 사용';

  @override
  String get fileSaveFailedTitle => '파일 저장 실패';

  @override
  String get fileSaveFailedWindowsMessage =>
      '현재 경로에 쓸 수 없습니다. 대상 폴더가 보호되었거나, 파일이 사용 중이거나, 경로에 쓰기 권한이 없을 수 있습니다.';

  @override
  String get fileSaveFailedGenericMessage =>
      '시스템이 파일을 저장하지 못했습니다. 다시 시도하거나, 시스템 설정을 확인하거나, 대신 파일 공유를 사용하세요.';

  @override
  String get retryLater => '나중에 다시 시도';

  @override
  String get exportSwitchedToShare => '내보내기가 파일 공유로 전환되었습니다';

  @override
  String get saveFailedRetry => '저장에 실패했습니다. 나중에 다시 시도하세요.';

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
  String get appInstanceBlockedTitle => 'Sked가 이미 열려 있습니다';

  @override
  String get appInstanceBlockedMessage =>
      '다른 Sked 창 또는 브라우저 탭에서 로컬 데이터를 사용 중입니다. 해당 창이나 탭을 닫고 다시 시도하세요.';

  @override
  String get appInstanceLeaseFailedTitle => '로컬 데이터를 사용할 수 없습니다';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked에서 로컬 데이터에 대한 단독 접근 권한을 확인하지 못했습니다. 데이터는 열리거나 변경되지 않았습니다. 저장소 접근 권한을 확인한 후 다시 시도하세요.';

  @override
  String get savingChanges => '변경 사항을 저장하는 중...';

  @override
  String get showApiKey => 'API 키 표시';

  @override
  String get hideApiKey => 'API 키 숨기기';

  @override
  String get importFailedCheckContent => '가져오기에 실패했습니다. 파일 내용을 확인하세요.';

  @override
  String get noImportableTimetables => '가져온 파일에서 사용할 수 있는 시간표를 찾지 못했습니다.';

  @override
  String importedTimetablesCount(int count) {
    return '시간표 $count개를 가져왔습니다';
  }

  @override
  String get periodTimesTitle => '교시 시간';

  @override
  String get importExport => '가져오기 및 내보내기';

  @override
  String get importPeriodTemplate => '교시 템플릿 가져오기';

  @override
  String get importPeriodTemplateText => '텍스트에서 교시 템플릿 가져오기';

  @override
  String get sharePeriodTemplate => '교시 템플릿 공유';

  @override
  String get saveTemplateToFile => '템플릿을 파일로 저장';

  @override
  String get exportPeriodTemplateText => '교시 템플릿을 텍스트로 내보내기';

  @override
  String get deletePeriodTimeSet => '교시 시간 세트 삭제';

  @override
  String get periodTimeSetName => '교시 시간 세트 이름';

  @override
  String get addOnePeriod => '교시 추가';

  @override
  String periodNumberLabel(int index) {
    return '$index교시';
  }

  @override
  String get deleteThisPeriod => '이 교시 삭제';

  @override
  String durationMinutes(int minutes) {
    return '길이 $minutes분';
  }

  @override
  String gapFromPrevious(int minutes) {
    return '이전 교시와 간격 $minutes분';
  }

  @override
  String get endTimeMustBeLater => '종료 시간은 시작 시간보다 늦어야 합니다';

  @override
  String get periodOverlapPrevious => '이 교시는 이전 교시와 겹칩니다';

  @override
  String get periodTimesSaved => '교시 시간이 저장되었습니다';

  @override
  String get deletePeriodTimeSetTitle => '교시 시간 세트 삭제';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return '\"$name\"을(를) 삭제할까요?';
  }

  @override
  String get currentPeriodTimeSet => '현재 교시 시간 세트';

  @override
  String importedPeriodTimesCount(int count) {
    return '교시 시간 $count개를 가져왔습니다';
  }

  @override
  String get periodFilePermissionTitle => '파일 권한 필요';

  @override
  String get androidFilePermissionMessage =>
      'Android에서 내보내기하려면 파일 접근 권한이 필요합니다. 저장을 계속하려면 권한을 허용하세요.';

  @override
  String get reauthorize => '다시 권한 부여';

  @override
  String get permissionPermanentlyDeniedTitle => '권한이 영구적으로 거부됨';

  @override
  String get permissionSettingsExportMessage =>
      '시스템 설정에서 파일 접근을 활성화한 뒤 돌아와 다시 내보내세요.';

  @override
  String get privacyPolicyTitle => '개인정보 처리방침';

  @override
  String get privacyPolicyEntryDesc =>
      '앱이 로컬 저장소, 학교 사이트 설정, 파일 가져오기/내보내기, 웹페이지 파싱, 외부 링크를 어떻게 처리하는지 확인하세요.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return '동의한 버전: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked는 로컬 우선 시간표 도구입니다. 시간표, 교시 시간 세트, 학교 사이트 설정은 기기 또는 브라우저에만 저장되며 자동으로 업로드되지 않습니다. 앱은 가져오기, 웹페이지 파싱, 공유, 외부 링크 열기와 같은 작업을 사용자가 명시적으로 실행할 때만 데이터를 처리합니다. 전체 개인정보 처리방침은 온라인에서 확인할 수 있습니다.';

  @override
  String get privacyPolicyLocalStorageTitle => '로컬 저장소';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => '가져오기 및 내보내기';

  @override
  String get privacyPolicyImportExportBody =>
      '앱은 사용자가 명시적으로 파일을 선택하거나 내보내기를 시작한 경우에만 시간표 JSON 파일, 학교 사이트 JSON 파일, 교시 템플릿 파일을 읽거나 씁니다. 이 파일들의 가져오기는 웹페이지 파싱을 함께 선택하지 않는 한 로컬 작업입니다. 사용자 지정 모델 목록을 가져오는 것도 명시적인 네트워크 작업이며, 사용자가 설정한 사용자 지정 엔드포인트에만 연결합니다.';

  @override
  String get privacyPolicySharingTitle => '공유';

  @override
  String get privacyPolicySharingBody =>
      '사용자가 명시적으로 공유 기능을 사용할 경우, 앱은 내보낸 파일을 시스템 공유 시트 또는 사용자가 선택한 대상 앱으로 전달합니다. 이후 파일 처리 방식은 사용자가 선택한 대상 앱 또는 서비스에 따라 달라집니다.';

  @override
  String get privacyPolicyExternalLinksTitle => '외부 링크';

  @override
  String get privacyPolicyExternalLinksBody =>
      'GitHub 저장소와 같은 외부 링크를 열면 앱은 해당 작업을 브라우저 또는 다른 외부 앱으로 넘깁니다. 그 이후의 데이터 처리는 사용자가 연 제3자에 의해 결정됩니다.';

  @override
  String get privacyPolicyNoCollectionTitle => '앱이 수집하지 않는 항목';

  @override
  String get privacyPolicyNoCollectionBody =>
      '앱은 Sked 계정을 요구하지 않으며, 분석, 광고 식별자, 클라우드 백업을 활성화하지 않습니다. 또한 학교 계정 비밀번호를 수집하기 위한 전용 입력란도 제공하지 않습니다. 앱 내부에서 학교 사이트에 로그인하는 경우, 그 상호작용은 사용자가 연 학교 페이지에서 이루어집니다.';

  @override
  String get privacyPolicyFutureFeatureTitle => '웹페이지 파싱';

  @override
  String get privacyPolicyFutureFeatureBody =>
      '학교 웹페이지 가져오기를 사용하거나 붙여넣은 시간표 텍스트 / HTML을 분석하면, 앱은 먼저 콘텐츠를 로컬에서 준비하고 정리한 뒤 제출한 시간표 텍스트, 페이지 텍스트 또는 HTML 콘텐츠, 선택적 페이지 제목과 URL, 현재 앱 언어, 파서 프롬프트 내용을 사용자가 설정한 OpenAI 호환 엔드포인트로 보냅니다. 모델 목록을 가져올 때도 같은 엔드포인트에 요청합니다. Sked는 내장 파서 엔드포인트를 제공하지 않으며, 개발자가 제어하는 시간표 파서 백엔드로 분석 요청을 보내지 않습니다. 사용자 지정 엔드포인트와 그 상위 서비스는 사용자가 선택한 서비스 제공자의 규칙에 따라 데이터를 저장, 전달, 제한, 삭제하거나 기타 방식으로 처리할 수 있습니다. http:// Base URL을 사용하는 경우 콘텐츠와 API 키가 전송 암호화로 보호되지 않을 수 있으므로 신뢰할 수 있는 기기, 네트워크, 엔드포인트 서비스에서만 사용하세요.';

  @override
  String get privacyPolicyUpdatesTitle => '정책 업데이트';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return '현재 개인정보 처리방침 버전은 $version입니다. 이후 버전에서 데이터 처리 방식이 변경되면 앱이 업데이트된 정책을 다시 읽고 동의하도록 요청할 수 있습니다.';
  }

  @override
  String get privacyGateTitle => '앱을 사용하기 전에 개인정보 처리방침에 동의해 주세요';

  @override
  String get privacyGateSummaryStorage =>
      '시간표, 교시 시간 세트, 학교 사이트 설정은 로컬에만 저장되며 개발자 서버로 자동 업로드되지 않습니다.';

  @override
  String get privacyGateSummaryImportExport =>
      '가져오기, 내보내기, 공유는 사용자가 명시적으로 시작할 때만 수행됩니다. 웹페이지 파싱은 사용자가 제출한 압축 내용만 설정한 파싱 엔드포인트로 전송하며, 저장 전에 파싱된 시간표를 검토할 수 있습니다.';

  @override
  String get privacyGateSummaryUpdates =>
      '이후 버전에서 데이터 처리 방식이 바뀌면 앱이 업데이트된 개인정보 처리방침을 다시 검토하도록 요청할 수 있습니다.';

  @override
  String get schoolWebImportEntry => '학교 웹페이지에서 가져오기';

  @override
  String get schoolWebImportEntryDesc => '학교 사이트의 현재 시간표 페이지를 가져옵니다.';

  @override
  String get schoolSitesManageEntry => '학교 사이트 관리';

  @override
  String get schoolSitesManageEntryDesc =>
      '학교 로그인 URL을 추가, 수정, 삭제하고 JSON 가져오기/내보내기를 지원합니다.';

  @override
  String get schoolSitesPageTitle => '학교 사이트 관리';

  @override
  String get schoolSitesImportJson => '학교 JSON 가져오기';

  @override
  String get schoolSitesShareJson => '학교 JSON 공유';

  @override
  String get schoolSitesSaveJson => '학교 JSON 저장';

  @override
  String get schoolSitesSaved => '학교 사이트가 저장되었습니다';

  @override
  String get schoolSitesImported => '학교 사이트를 가져왔습니다';

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
  String get schoolSitesEmpty => '아직 학교 사이트 설정이 없습니다.';

  @override
  String get schoolSitesNameLabel => '학교 이름';

  @override
  String get schoolSitesLoginUrlLabel => '로그인 URL';

  @override
  String get schoolSitesAdd => '학교 추가';

  @override
  String get schoolSitesEdit => '학교 수정';

  @override
  String get schoolSitesDeleteTitle => '학교 삭제';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return '\"$name\"을(를) 삭제할까요?';
  }

  @override
  String get schoolSitesFormInvalid => '먼저 학교 이름과 로그인 URL을 입력하세요.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry => '시간표 페이지 내용을 붙여넣어 가져오기';

  @override
  String get schoolHtmlImportEntryDesc =>
      '시간표 정보가 포함된 소스 코드 또는 원본 페이지 내용을 직접 붙여넣습니다.';

  @override
  String get schoolHtmlImportPageTitle => '페이지 내용에서 시간표 파싱';

  @override
  String get schoolHtmlImportUrlLabel => '원본 URL (선택 사항)';

  @override
  String get schoolHtmlImportTitleLabel => '페이지 제목 (선택 사항)';

  @override
  String get schoolHtmlImportHtmlLabel => '페이지 내용';

  @override
  String get schoolHtmlImportHtmlHint =>
      '시간표 정보가 포함된 소스 코드 또는 원본 페이지 내용을 여기에 붙여넣으세요.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'HTML뿐 아니라 시간표 정보가 포함된 모든 내용을 파싱하여 가져올 수 있습니다.';

  @override
  String get schoolHtmlImportCompress => '내용 정리';

  @override
  String get schoolHtmlImportCompressed => '내용이 정리되었습니다';

  @override
  String get schoolHtmlImportCompressFirst => '먼저 내용을 정리하세요.';

  @override
  String get schoolHtmlImportSubmit => '파싱 후 가져오기';

  @override
  String get schoolImportContentTruncated =>
      '이 페이지가 안전한 가져오기 한도에 도달했습니다. 캡처된 부분만 분석을 위해 전송됩니다.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      '파싱에 시간이 걸릴 수 있습니다. 잠시만 기다려 주세요.';

  @override
  String get schoolHtmlImportEmpty => '먼저 페이지 HTML을 붙여넣으세요.';

  @override
  String get schoolHtmlImportReturnToWebPage => '웹페이지로 돌아가기';

  @override
  String get schoolWebImportPageTitle => '학교 웹페이지 가져오기';

  @override
  String get schoolWebImportPreview => '가져오기 미리보기';

  @override
  String schoolWebImportCourseCount(int count) {
    return '수업 $count개';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '교시 $count개';
  }

  @override
  String get schoolWebImportPageTitleLabel => '페이지 제목';

  @override
  String get schoolWebImportParserUsed => '파서';

  @override
  String get schoolWebImportWarnings => '가져오기 참고사항';

  @override
  String get schoolWebImportParserDetails => '분석 세부정보';

  @override
  String get schoolWebImportExpandParserDetails => '분석 세부정보 펼치기';

  @override
  String get schoolWebImportCollapseParserDetails => '분석 세부정보 접기';

  @override
  String get schoolWebImportOpenPageHint =>
      '앱 내에서 학교 사이트에 로그인한 뒤, 시간표 페이지로 직접 이동하세요.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      '이 플랫폼은 아직 내장 웹 로그인 기능을 지원하지 않습니다. WebView를 지원하는 플랫폼을 사용하세요.';

  @override
  String get schoolWebImportSelectSchool => '학교 선택';

  @override
  String get schoolWebImportNoSchools =>
      '사용 가능한 학교 설정이 없습니다. 먼저 school_sites.json을 확인하세요.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      '학교 설정을 불러오지 못했습니다. JSON 파일 형식을 확인하세요.';

  @override
  String get schoolWebImportImportCurrentPage => '현재 페이지 가져오기';

  @override
  String get schoolWebImportGoBack => '이전 페이지';

  @override
  String get schoolWebImportLoadingPage => '페이지를 불러오는 중…';

  @override
  String get schoolWebImportParsing => '현재 페이지를 파싱하는 중…';

  @override
  String get schoolWebImportLoadFailed =>
      '페이지 로드에 실패했습니다. 새로고침하거나 나중에 다시 시도하세요.';

  @override
  String get schoolWebImportLoadTimedOut =>
      '페이지 로드 시간이 초과되었습니다. 새로고침 후 다시 시도하세요.';

  @override
  String get schoolWebImportUnknownOrigin => '알 수 없는 사이트';

  @override
  String get schoolWebImportCrossOriginTitle => '다른 사이트로 이동할까요?';

  @override
  String schoolWebImportCrossOriginMessage(Object origin) {
    return '학교 로그인 과정에서 다른 사이트를 열어야 할 수 있습니다. 현재 가져오기 세션에서 이 대상을 신뢰하는 경우에만 계속하세요:\n\n$origin';
  }

  @override
  String get schoolWebImportEmptyPage => '현재 페이지 내용이 비어 있어 아직 가져올 수 없습니다.';

  @override
  String get schoolWebImportSuccess => '웹 시간표를 가져왔습니다';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSettingsLocationHint =>
      'Configure it in Settings > Data & security > AI API configuration.';

  @override
  String get schoolImportParserSourceTitle => '파서 소스';

  @override
  String get schoolImportParserSourceCustomOpenAi => '사용자 지정 OpenAI 호환';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi => '사용자 지정 OpenAI 호환 파서';

  @override
  String get schoolImportParserCustomPromptTitle => '사용자 지정 프롬프트';

  @override
  String get schoolImportParserCustomPromptDescription =>
      '여기에서 내장 파서 프롬프트를 수정하세요. 변경 사항은 사용자 지정 OpenAI 호환 파서에만 적용됩니다.';

  @override
  String get schoolImportParserCustomPromptHint =>
      '기본적으로 여기에 내장 프롬프트가 로드됩니다. 비우면 내장 버전으로 되돌아갑니다.';

  @override
  String get schoolImportParserResetDefaultPrompt => '기본 프롬프트로 재설정';

  @override
  String get schoolImportParserBaseUrl => 'Base URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL은 호스트가 포함된 HTTP 또는 HTTPS URL이어야 합니다.';

  @override
  String get schoolImportParserApiKey => 'API key';

  @override
  String get schoolImportParserModel => '모델';

  @override
  String get schoolImportParserFetchModels => '모델 목록 가져오기';

  @override
  String get schoolImportParserFetchingModels => '모델을 가져오는 중...';

  @override
  String get schoolImportParserNoModelsFound => '엔드포인트에서 모델을 반환하지 않았습니다.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      '모델을 가져올 수 없습니다. 엔드포인트를 확인한 후 다시 시도하세요.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return '모델 $count개를 가져왔습니다';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle => '암호화되지 않은 HTTP 엔드포인트를 사용할까요?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'API 키와 시간표 내용은 전송 중에 읽히거나 변경될 수 있습니다. 이 기기, 네트워크 및 엔드포인트를 신뢰하는 경우에만 계속하세요. 이 승인은 Sked를 닫을 때까지 유효합니다.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      '사용자 지정 파서 설정이 완전하지 않습니다. 먼저 Base URL, API key, 모델을 입력하세요.';

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
    return '파서: 사용자 지정 ($model)';
  }

  @override
  String get privacyViewFullPolicy => '전체 개인정보 처리방침 보기';

  @override
  String get privacyAgreeAndContinue => '동의하고 계속';

  @override
  String get privacyDecline => '거부';

  @override
  String get privacyDeclineWebHint =>
      '이 브라우저 환경에서는 앱이 페이지를 대신 닫을 수 없습니다. 동의하지 않는 경우 이 탭이나 창을 직접 닫아 주세요.';

  @override
  String get defaultPeriodTimeSetName => '기본 교시';

  @override
  String get periodTimeSetFallbackName => '교시 시간';

  @override
  String get untitledTimetableName => '제목 없는 시간표';

  @override
  String get newTimetableName => '새 시간표';

  @override
  String get newPeriodTimeSetName => '새 교시 시간 세트';

  @override
  String get emptyTimetableName => '빈 시간표';

  @override
  String importedPeriodTimeSetName(Object name) {
    return '$name 교시';
  }

  @override
  String get importFileTypeMismatchMessage => '가져오기 파일 유형이 일치하지 않습니다.';

  @override
  String get importFileVersionUnsupportedMessage =>
      '이 가져오기 파일 버전은 아직 지원되지 않습니다.';

  @override
  String get noPeriodTimesInImportMessage => '가져오기 파일에서 교시 시간을 찾지 못했습니다.';

  @override
  String get selectAtLeastOneTimetableMessage => '시간표를 하나 이상 선택하세요.';

  @override
  String get noExportableTimetableMessage => '내보낼 수 있는 시간표가 없습니다.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      '현재 시간표를 교체하려면 시간표 하나만 선택할 수 있습니다.';

  @override
  String get noActiveTimetableToReplaceMessage => '교체할 현재 시간표가 없습니다.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return '이 교시 시간 세트는 아직 시간표 $count개에서 사용 중입니다. 삭제하기 전에 다른 세트로 다시 지정하세요.';
  }

  @override
  String get weekdayMonday => '월요일';

  @override
  String get weekdayTuesday => '화요일';

  @override
  String get weekdayWednesday => '수요일';

  @override
  String get weekdayThursday => '목요일';

  @override
  String get weekdayFriday => '금요일';

  @override
  String get weekdaySaturday => '토요일';

  @override
  String get weekdaySunday => '일요일';

  @override
  String get weekdayShortMonday => '월';

  @override
  String get weekdayShortTuesday => '화';

  @override
  String get weekdayShortWednesday => '수';

  @override
  String get weekdayShortThursday => '목';

  @override
  String get weekdayShortFriday => '금';

  @override
  String get weekdayShortSaturday => '토';

  @override
  String get weekdayShortSunday => '일';

  @override
  String get monthJanuary => '1월';

  @override
  String get monthFebruary => '2월';

  @override
  String get monthMarch => '3월';

  @override
  String get monthApril => '4월';

  @override
  String get monthMay => '5월';

  @override
  String get monthJune => '6월';

  @override
  String get monthJuly => '7월';

  @override
  String get monthAugust => '8월';

  @override
  String get monthSeptember => '9월';

  @override
  String get monthOctober => '10월';

  @override
  String get monthNovember => '11월';

  @override
  String get monthDecember => '12월';

  @override
  String get semesterWeeksWholeTerm => '전체 학기';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return '$start-$end주차';
  }

  @override
  String semesterWeeksList(Object value) {
    return '$value주차';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => '시작 모드 선택';

  @override
  String get firstLaunchSubtitle =>
      '가장 많이 사용하는 작업 공간을 선택하세요. 나중에 모드를 전환할 수 있습니다.';

  @override
  String get firstLaunchStudentDesc => '시간표, 과목, 주차, 교시 시간, 가져오기를 관리합니다.';

  @override
  String get firstLaunchGeneralDesc => '카테고리, 이벤트, 알림, JSON / ICS 데이터를 관리합니다.';

  @override
  String get firstLaunchStartStudent => '시간표로 시작';

  @override
  String get firstLaunchStartGeneral => '일정으로 시작';

  @override
  String get firstLaunchPrivacyConsentBefore => '시작 작업 공간을 선택하면 ';

  @override
  String get firstLaunchPrivacyConsentLink => '개인정보 처리방침';

  @override
  String get firstLaunchPrivacyConsentAfter => '을 읽고 동의한 것으로 간주됩니다.';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => '오늘';

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
  String get generalDisplaySettingsDesc => '보기, 도구 모음, 날짜 형식 및 빠른 추가';

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
  String get viewWeek => '주';

  @override
  String get viewDay => '일';

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
  String get schoolWebImportSignInConsentTitle => '학교 로그인 페이지를 열까요?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return '학교 로그인 과정에서 양식 또는 서버 리디렉션을 통해 학교와 로그인 제공업체에 인증 정보가 전송될 수 있습니다. Android에서는 이러한 전송을 매번 중지하여 대상을 별도로 확인할 수 없습니다. 현재 가져오기 세션에서 해당 서비스를 신뢰하는 경우에만 계속하세요:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      '안전하지 않은 학교 로그인을 여시겠어요?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return '이 학교 로그인은 HTTP를 사용합니다. 이 연결을 감시하거나 변경할 수 있는 사람은 로그인 정보와 페이지 내용을 읽거나 바꿀 수 있습니다. 다음 사이트에 대한 이러한 위험을 감수하는 경우에만 계속하세요:\n\n$origin';
  }

  @override
  String get developerModeTitle => '개발자 모드';

  @override
  String get developerModeDescription =>
      '화면과 상호작용을 확인할 수 있도록 전체 샘플 데이터를 추가하는 도구입니다.';

  @override
  String get developerSampleLanguage => '샘플 데이터 언어';

  @override
  String get developerSampleChinese => '중국어';

  @override
  String get developerSampleEnglish => '영어';

  @override
  String get developerSampleDataDescription =>
      '기존 데이터를 바꾸지 않고 시간표 1개와 카테고리 및 일정 묶음을 추가합니다.';

  @override
  String get developerAddSampleData => '샘플 데이터 추가';

  @override
  String get developerSampleDataAdded => '샘플 시간표와 일정 데이터를 추가했습니다.';

  @override
  String get developerModeLongPressHint => '개발자 모드를 열려면 3초 동안 길게 누르세요';

  @override
  String get collapseWorkspaceNavigation => '작업 공간 탐색 접기';

  @override
  String get expandWorkspaceNavigation => '작업 공간 탐색 펼치기';
}
