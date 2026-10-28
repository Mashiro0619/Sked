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
  String get schoolImportParsePageTitle => '시간표 분석';

  @override
  String get schoolImportParsePageParsing => '분석 중…';

  @override
  String get schoolImportParsePageFailed => '분석 실패';

  @override
  String get schoolImportParseErrorMessage =>
      '시간표를 분석할 수 없습니다. 내용, 분석 설정 및 네트워크 연결을 확인한 후 다시 시도하세요.';

  @override
  String get schoolImportParsePageContinue => '계속';

  @override
  String get schoolImportExpandWarnings => '가져오기 경고 펼치기';

  @override
  String get schoolImportCollapseWarnings => '가져오기 경고 접기';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return '일부 수업은 $week주차까지 계속됩니다.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle => '현재 시간표를 바꿀까요?';

  @override
  String get replaceCurrentTimetableConfirmMessage => '가져온 시간표로 현재 시간표를 바꿉니다.';

  @override
  String get createTimetable => '새 시간표';

  @override
  String get jumpToWeek => '주차로 이동';

  @override
  String get timetable => '시간표';

  @override
  String get themeWorkspaceSchedule => '일정';

  @override
  String get timetableName => '시간표 이름';

  @override
  String get timetableNameRequired => '시간표 이름을 입력하세요';

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
  String get customFieldsInvalidJson => '유효한 JSON 객체를 입력하거나 필드를 비우세요.';

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
  String get settingsSectionAppearance => '화면 모양';

  @override
  String get settingsSectionWorkspace => '작업 공간';

  @override
  String get settingsSectionAbout => 'Sked 정보';

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
  String get timetableHorizontalLayoutSection => '가로 배치 및 제스처';

  @override
  String get fitDaySelectorToWidth => '요일 선택기를 화면 너비에 맞추기';

  @override
  String get fitDaySelectorToWidthHint =>
      '가능하면 7일을 모두 화면 안에 표시합니다. 끄면 고정 너비로 표시하고 스크롤할 수 있습니다.';

  @override
  String get fitWeekColumnsToWidth => '시간표 열을 화면 너비에 맞추기';

  @override
  String get enableWeekSwipeNavigation => '스와이프로 주 바꾸기';

  @override
  String get enableWeekSwipeNavigationHint =>
      '좌우로 스와이프하여 다른 주로 이동합니다. 고정 너비를 사용할 때는 먼저 끝까지 스크롤하세요.';

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
  String get includePrereleaseUpdates => '사전 출시 업데이트 받기';

  @override
  String get includePrereleaseUpdatesDesc =>
      '불안정할 수 있는 Alpha, Beta, RC 버전도 확인합니다. 끄면 안정 버전만 제공됩니다.';

  @override
  String get currentVersionLabel => '현재 버전';

  @override
  String get newVersionAvailable => '새 버전이 있습니다';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get ignoreThisVersion => '이 버전 무시';

  @override
  String get openUpdatesFailed => '업데이트 링크를 열 수 없습니다';

  @override
  String get updateCheckFailedTitle => '업데이트 확인 실패';

  @override
  String get githubRepository => 'GitHub 저장소';

  @override
  String get googlePlayStoreDesc => 'Google Play에서 Sked 보기';

  @override
  String get openGooglePlayFailed => 'Google Play를 열 수 없습니다';

  @override
  String get microsoftStoreDesc => 'Microsoft Store에서 Sked 보기';

  @override
  String get openMicrosoftStoreFailed => 'Microsoft Store를 열 수 없습니다';

  @override
  String get starSkedOnGithub => 'GitHub에서 Sked에 스타를 남겨 주세요!';

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
  String get studentDayNextCourse => 'Next course';

  @override
  String get studentDayNoMoreCourses =>
      'No later courses in this timetable\'s semester.';

  @override
  String get studentDayEmpty => '이 날은 수업이 없습니다';

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
  String get periodTimesUnsavedExitTitle => '변경 사항이 저장되지 않았습니다';

  @override
  String get periodTimesSaveFailureExitMessage =>
      '최근 교시 시간 변경 사항을 저장하지 못했습니다. 다시 시도하거나, 계속 편집하거나, 변경 사항을 버릴 수 있습니다.';

  @override
  String get periodTimesInvalidExitMessage =>
      '일부 교시 시간이 올바르지 않습니다. 수정한 뒤 저장하거나, 변경 사항을 버리고 나가세요.';

  @override
  String get discardChangesAndExit => '변경 사항을 버리고 나가기';

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
      'Sked는 로컬 저장을 우선하는 시간표 도구입니다. 시간표, 일반 일정, 교시 시간 세트 및 학교 사이트 설정은 기기 또는 브라우저에만 저장되며 자동으로 업로드되지 않습니다. 앱은 가져오기, 시간표 텍스트 / HTML 분석, 학교 웹페이지 가져오기, 공유 또는 외부 링크 열기 같은 작업을 사용자가 명시적으로 실행할 때만 데이터를 처리합니다. 전체 개인정보 처리방침은 온라인에서 확인할 수 있습니다.';

  @override
  String get privacyGateTitle => '앱을 사용하기 전에 개인정보 처리방침에 동의해 주세요';

  @override
  String get privacyGateSummaryStorage =>
      '시간표, 일반 일정, 교시 시간 세트 및 학교 사이트 설정은 로컬에만 저장되며 개발자 서버에 자동으로 업로드되지 않습니다.';

  @override
  String get privacyGateSummaryImportExport =>
      '가져오기, 내보내기, 전체 백업 및 공유는 사용자가 명시적으로 시작할 때만 수행됩니다. 앱의 전체 백업에는 사용자 지정 API 키가 포함되지 않으며, 시간표 텍스트 / HTML 분석은 제출한 내용만 설정된 분석 엔드포인트로 전송합니다.';

  @override
  String get privacyGateSummaryUpdates =>
      '이후 버전에서 데이터 처리 방식이 바뀌면 앱이 업데이트된 개인정보 처리방침을 다시 검토하도록 요청할 수 있습니다.';

  @override
  String get schoolWebImportEntry => '학교 웹페이지에서 가져오기';

  @override
  String get schoolWebImportEntryDesc => '학교 사이트의 현재 시간표 페이지를 가져옵니다.';

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
  String get schoolSitesImportPreviewTitle => '학교 사이트 가져오기 검토';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '유효한 사이트 $validCount개, 잘못된 항목 $invalidCount개입니다.';
  }

  @override
  String get schoolSitesImportEmptyPreview => '파일의 학교 사이트 목록이 비어 있습니다.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return '$position번 항목이 올바르지 않아 건너뜁니다.';
  }

  @override
  String get schoolSitesImportMerge => '합치기';

  @override
  String get schoolSitesImportReplace => '바꾸기';

  @override
  String get schoolSitesImportReplaceConfirmTitle => '현재 학교 사이트를 바꿀까요?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return '현재 사이트 $currentCount개를 삭제하고 가져온 사이트 $importedCount개를 저장합니다. 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle => '학교 사이트 데이터를 복구해야 합니다';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      '학교 사이트 파일과 백업을 읽지 못했습니다. 쓰기를 차단하기 전에 보호용 사본을 만들었습니다.';

  @override
  String get schoolSitesRecoveryIoFailureTitle => '학교 사이트 저장소를 사용할 수 없습니다';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      '현재 학교 사이트 저장소에 접근할 수 없습니다. 저장소 접근 권한이나 기기 상태를 확인한 뒤 다시 시도하세요. 현재 사이트 데이터는 덮어쓰지 않습니다.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      '복구 파일이나 영향을 받은 저장 위치가 아래에 표시됩니다. 사이트 목록을 복구할 때까지 파일을 변경하지 마세요.';

  @override
  String get schoolSitesRecoveryStartFreshAction => '학교 사이트 없이 새로 시작';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      '빈 학교 사이트 목록으로 시작할까요?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      '보호용 사본은 유지하지만 새 학교 사이트 파일을 빈 상태로 만듭니다. 먼저 복구를 다시 시도하지 않아도 되는 경우에만 계속하세요.';

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
  String get schoolWebImportUnsupportedPlatform =>
      '이 플랫폼은 아직 내장 웹 로그인 기능을 지원하지 않습니다. WebView를 지원하는 플랫폼을 사용하세요.';

  @override
  String get schoolWebImportNoSchools =>
      '사용 가능한 학교 설정이 없습니다. 먼저 school_sites.json을 확인하세요.';

  @override
  String get schoolWebImportSchoolLoadFailed => '학교 설정을 불러오지 못했습니다. 다시 시도하세요.';

  @override
  String get schoolWebImportImportCurrentPage => '현재 페이지 가져오기';

  @override
  String get schoolWebImportLoadFailed =>
      '페이지 로드에 실패했습니다. 새로고침하거나 나중에 다시 시도하세요.';

  @override
  String get schoolWebImportUnknownOrigin => '알 수 없는 사이트';

  @override
  String get schoolWebImportExitTitle => '브라우저를 종료할까요?';

  @override
  String get schoolWebImportExitMessage => '페이지가 닫힙니다. 아직 가져오지 않은 내용은 사라집니다.';

  @override
  String get schoolWebImportExitConfirm => '종료';

  @override
  String get schoolWebImportEmptyPage => '현재 페이지 내용이 비어 있어 아직 가져올 수 없습니다.';

  @override
  String get schoolWebImportSuccess => '웹 시간표를 가져왔습니다';

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
  String get schoolImportParserSettingsTitle => '시간표 분석 API';

  @override
  String get schoolImportParserSettingsDesc =>
      '시간표 가져오기에 사용할 OpenAI 호환 API를 설정합니다. 대화형 도우미 설정이 아닙니다.';

  @override
  String get schoolImportParserSourceTitle => '파서 소스';

  @override
  String get schoolImportParserSourceCustomOpenAi => '사용자 지정 OpenAI 호환';

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
  String get schoolImportParserBaseUrl => '기본 URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL은 호스트가 포함된 HTTP 또는 HTTPS URL이어야 합니다.';

  @override
  String get schoolImportParserApiKey => 'API 키';

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
      '사용자 지정 API 키는 지원되는 경우 플랫폼의 보안 저장소를 통해 저장됩니다. 사용자 지정 분석기의 인증 정보와 HTTP 연결 주소는 신뢰할 수 있는 기기, 브라우저, 네트워크에서만 사용하세요.';

  @override
  String get schoolImportHttpConfirmationTitle => '암호화되지 않은 HTTP 엔드포인트를 사용할까요?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'API 키와 시간표 내용은 전송 중에 읽히거나 변경될 수 있습니다. 이 기기, 네트워크 및 엔드포인트를 신뢰하는 경우에만 계속하세요. 이 승인은 Sked를 닫을 때까지 유효합니다.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      '사용자 지정 파서 설정이 완전하지 않습니다. 먼저 Base URL, API key, 모델을 입력하세요.';

  @override
  String get clearAppData => '데이터 지우기';

  @override
  String get clearAppDataDesc => '모든 로컬 Sked 데이터를 영구 삭제하고 앱 종료';

  @override
  String get clearAppDataConfirmTitle => 'Sked 데이터를 모두 지울까요?';

  @override
  String get clearAppDataConfirmMessage =>
      '시간표, 일정, 설정, 학교 사이트, 로컬 백업, 복구 사본, AI API 키를 영구 삭제한 다음 Sked를 종료합니다. 다른 곳으로 내보낸 파일은 삭제하지 않습니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get clearAppDataAction => '데이터를 지우고 종료';

  @override
  String get clearAppDataFailed =>
      '모든 로컬 데이터를 지우지 못했습니다. 다시 시도할 수 있도록 Sked를 열어 둡니다.';

  @override
  String get clearAppDataExitFailed =>
      '로컬 데이터는 지웠지만 Sked를 종료하지 못했습니다. 다시 사용하기 전에 앱을 직접 닫아 주세요.';

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
  String get noPeriodTimesInImportMessage => '가져오기 파일에서 교시 시간을 찾지 못했습니다.';

  @override
  String get selectAtLeastOneTimetableMessage => '시간표를 하나 이상 선택하세요.';

  @override
  String get noExportableTimetableMessage => '내보낼 수 있는 시간표가 없습니다.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      '현재 시간표를 교체하려면 시간표 하나만 선택할 수 있습니다.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      '바꾸기 대상으로 선택한 시간표를 사용할 수 없습니다. 다시 선택하세요.';

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
  String get generalSchedule => '일반 일정';

  @override
  String get studentTimetable => '학생 시간표';

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
  String get firstLaunchPrivacyConsentBefore => '시작 작업 공간을 선택하면 ';

  @override
  String get firstLaunchPrivacyConsentLink => '개인정보 처리방침';

  @override
  String get firstLaunchPrivacyConsentAfter => '을 읽고 동의한 것으로 간주됩니다.';

  @override
  String get switchMode => '모드 전환';

  @override
  String get switchToStudentTimetable => '학생 시간표로 전환';

  @override
  String get today => '오늘';

  @override
  String get addEvent => '일정 추가';

  @override
  String get editEvent => '일정 편집';

  @override
  String get eventTitle => '제목';

  @override
  String get eventTitleRequired => '제목을 입력하세요';

  @override
  String get eventStartTime => '시작 시간';

  @override
  String get eventEndTime => '종료 시간';

  @override
  String get eventDate => '날짜';

  @override
  String get eventTime => '시간';

  @override
  String get eventNotes => '메모';

  @override
  String get eventColor => '색상';

  @override
  String get eventRecurrence => '반복';

  @override
  String get recurrenceNone => '반복 안 함';

  @override
  String get recurrenceWeekly => '매주';

  @override
  String get recurrenceEndDate => '종료일';

  @override
  String get repeatsWeekly => '매주 반복';

  @override
  String recurrenceUntil(Object date) {
    return '$date까지';
  }

  @override
  String get switchToGeneralSchedule => '일반 일정으로 전환';

  @override
  String get generalDisplaySettings => '일반 일정 표시 설정';

  @override
  String get generalDisplaySettingsDesc => '보기, 도구 모음, 날짜 형식 및 빠른 추가';

  @override
  String get closePopupOnOutsideTap => '바깥을 누르면 팝업 닫기';

  @override
  String get showGridLines => '격자선 표시';

  @override
  String get generalScheduleImportExport => '카테고리 가져오기 및 내보내기';

  @override
  String get generalScheduleImportExportDesc => '일정 카테고리 가져오기 또는 공유';

  @override
  String get importGeneralSchedules => '카테고리 가져오기';

  @override
  String get importGeneralSchedulesDesc => 'JSON 파일에서 카테고리 읽기';

  @override
  String get shareGeneralSchedules => '카테고리 공유';

  @override
  String get shareGeneralSchedulesDesc => '카테고리를 JSON 파일로 공유';

  @override
  String get saveGeneralSchedules => '카테고리 저장';

  @override
  String get saveGeneralSchedulesDesc => '카테고리를 JSON 파일로 저장';

  @override
  String get selectSchedulesToExport => '내보낼 카테고리 선택';

  @override
  String get selectSchedulesToImport => '가져올 카테고리 선택';

  @override
  String generalScheduleEventCount(int count) {
    return '일정: $count개';
  }

  @override
  String importedSchedulesCount(int count) {
    return '카테고리 $count개를 가져왔습니다';
  }

  @override
  String get replaceActiveSchedulePrompt => '새 카테고리로 추가할까요, 아니면 기존 카테고리를 바꿀까요?';

  @override
  String get addAsNewSchedule => '새 카테고리로 추가';

  @override
  String get selectAtLeastOneScheduleMessage => '카테고리를 하나 이상 선택하세요.';

  @override
  String get noExportableScheduleMessage => '내보낼 카테고리가 없습니다.';

  @override
  String get noSchedulesInImportMessage => '가져올 파일에 카테고리가 없습니다.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      '바꾸기에 사용할 카테고리를 가져온 항목에서 하나만 선택하세요.';

  @override
  String get noActiveScheduleToReplaceMessage => '선택한 교체 대상 카테고리를 사용할 수 없습니다.';

  @override
  String get calendars => '카테고리';

  @override
  String get calendar => '카테고리';

  @override
  String get viewWeek => '주';

  @override
  String get viewDay => '일';

  @override
  String get viewList => '목록';

  @override
  String get viewMonth => '월';

  @override
  String visibleCategoryCount(int count) {
    return '카테고리 $count개';
  }

  @override
  String get noVisibleCategories => '표시 중인 카테고리가 없습니다';

  @override
  String get selectCategoryToReplace => '바꿀 카테고리 선택';

  @override
  String get replaceCategory => '카테고리 바꾸기';

  @override
  String get deleteEventTitle => '일정 삭제';

  @override
  String get deleteEventConfirmation => '이 일정이 영구 삭제됩니다.';

  @override
  String get deleteRecurringEventTitle => '반복 일정 삭제';

  @override
  String get eventDuplicated => '일정을 복제했습니다';

  @override
  String get allDay => '종일';

  @override
  String get collapseAllDayTimeline => '종일 일정 접기';

  @override
  String get expandAllDayTimeline => '종일 일정 펼치기';

  @override
  String allDayEventsCount(int count) {
    return '종일 일정 $count개';
  }

  @override
  String moreEvents(int count) {
    return '+$count개 더';
  }

  @override
  String get noMatchingEvents => '일치하는 일정이 없습니다';

  @override
  String get noUpcomingEvents => '예정된 일정이 없습니다';

  @override
  String get addCalendar => '카테고리 추가';

  @override
  String get newCalendar => '새 카테고리';

  @override
  String get hideCalendar => '카테고리 숨기기';

  @override
  String get showCalendar => '카테고리 표시';

  @override
  String get rename => '이름 바꾸기';

  @override
  String get renameCalendar => '카테고리 이름 바꾸기';

  @override
  String get name => '이름';

  @override
  String get deleteCalendar => '카테고리 삭제';

  @override
  String deleteCalendarMessage(Object name) {
    return '\"$name\"을(를) 삭제할까요?';
  }

  @override
  String get deleteThisOccurrence => '이번 일정만 삭제';

  @override
  String get deleteFutureOccurrences => '이번 및 이후 일정 삭제';

  @override
  String get deleteAllOccurrences => '전체 반복 일정 삭제';

  @override
  String get duplicateEvent => '복제';

  @override
  String get repeatsDaily => '매일 반복';

  @override
  String get repeatsMonthly => '매월 반복';

  @override
  String repeatsEvery(int interval, Object unit) {
    return '$interval $unit마다 반복';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count회';
  }

  @override
  String get recurrenceDaily => '매일';

  @override
  String get recurrenceMonthly => '매월';

  @override
  String get recurrenceCustom => '사용자 지정';

  @override
  String get recurrenceEvery => '간격';

  @override
  String get recurrenceUnit => '단위';

  @override
  String get recurrenceDays => '일';

  @override
  String get recurrenceWeeks => '주';

  @override
  String get recurrenceMonths => '개월';

  @override
  String get recurrenceRepeatCount => '반복 횟수';

  @override
  String get recurrenceNoLimit => '제한 없음';

  @override
  String get recurrencePositiveNumber => '양수를 입력하세요';

  @override
  String get clearEndDate => '종료일 지우기';

  @override
  String get pickDate => '날짜 선택';

  @override
  String get pickTime => '시간 선택';

  @override
  String get reminder => '알림';

  @override
  String get reminderAtStart => '시작 시';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes분 전';
  }

  @override
  String get reminderHourBefore => '1시간 전';

  @override
  String get reminderDayBefore => '1일 전';

  @override
  String get markReminderHandled => '확인 완료로 표시';

  @override
  String get restoreReminder => '앱 내 알림 복원';

  @override
  String get reminderHandled => '앱 내 알림을 확인 완료로 표시했습니다';

  @override
  String get reminderRestored => '앱 내 알림을 복원했습니다';

  @override
  String get reminderUpcoming => '예정됨';

  @override
  String get generalFitWeekColumnsToWidth => '주 보기를 화면에 맞추기';

  @override
  String get showWeekends => '주말 표시';

  @override
  String get startHour => '표시 시작 시간';

  @override
  String get endHour => '표시 종료 시간';

  @override
  String get timeGridDensity => '시간 격자 간격';

  @override
  String get timeGridHourHeight => '시간당 행 높이';

  @override
  String get timeGridHourHeightHint =>
      '15분, 30분, 60분의 격자 간격은 그대로 두고 일간 및 주간 보기의 세로 크기를 조절합니다.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'JSON 파일 가져오기';

  @override
  String get pasteJson => 'JSON 붙여넣기';

  @override
  String get importGeneralSchedulesJsonTextDesc => '복사한 JSON에서 카테고리 가져오기';

  @override
  String get importIcsFile => 'ICS 파일 가져오기';

  @override
  String get importIcsFileDesc => '.ics 캘린더 파일에서 일정 읽기';

  @override
  String get pasteIcs => 'ICS 붙여넣기';

  @override
  String get pasteIcsDesc => '복사한 캘린더 텍스트에서 일정 가져오기';

  @override
  String get copyJson => 'JSON 복사';

  @override
  String get copyJsonDesc => '선택한 카테고리를 JSON 텍스트로 복사';

  @override
  String get shareIcs => 'ICS 공유';

  @override
  String get shareIcsDesc => '선택한 캘린더를 .ics로 공유';

  @override
  String get saveIcs => 'ICS 저장';

  @override
  String get saveIcsDesc => '선택한 캘린더를 .ics로 저장';

  @override
  String get copyIcs => 'ICS 복사';

  @override
  String get copyIcsDesc => '선택한 캘린더를 ICS 텍스트로 복사';

  @override
  String get importIcs => 'ICS 가져오기';

  @override
  String get icsContent => 'ICS 내용';

  @override
  String get pasteIcsContentHint => '여기에 BEGIN:VCALENDAR로 시작하는 내용을 붙여넣으세요';

  @override
  String get icsReminderExportTitle => 'ICS 내보내기에는 알림이 포함되지 않습니다';

  @override
  String get icsReminderExportMessage =>
      '내보낸 ICS에는 알림이 포함되지 않습니다. 알림 설정을 유지하려면 JSON을 선택하세요.';

  @override
  String get icsReminderExportJsonAction => 'JSON 내보내기';

  @override
  String get icsReminderExportContinueAction => 'ICS로 계속';

  @override
  String get icsReminderImportNotice =>
      'ICS에서 가져온 일정의 알림은 꺼집니다. 알림 설정을 복원하려면 JSON을 사용하세요.';

  @override
  String get icsReminderReplaceTitle => '일정과 알림을 바꿀까요?';

  @override
  String icsReminderReplaceMessage(String calendar) {
    return '“$calendar”을(를) ICS 일정으로 바꾸면 이 카테고리의 일정을 덮어쓰고 해당 알림을 끕니다. 먼저 JSON 백업을 내보내려면 취소하세요. 또는 뒤로 돌아가 새 카테고리로 추가하세요.';
  }

  @override
  String importIcsPreviewPrompt(int count) {
    return '일정 $count개를 찾았습니다. 새 카테고리로 추가할까요, 아니면 기존 카테고리를 바꿀까요?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return '카테고리 $count개를 가져왔으며 경고가 $warningCount개 있습니다';
  }

  @override
  String get importWarningSkippedMissingStart => '시작 시간이 없는 일정을 건너뛰었습니다.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      '지원하지 않는 시작 시간을 가진 일정을 건너뛰었습니다.';

  @override
  String get importWarningAdjustedEnd => '시작 시간보다 늦지 않은 종료 시간을 조정했습니다.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return '지원하지 않는 ICS 필드를 무시했습니다: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return '지원하지 않는 반복 주기를 무시했습니다: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs => 'ICS로 복사할 캘린더 선택';

  @override
  String get selectCalendarsToExportIcs => 'ICS로 내보낼 캘린더 선택';

  @override
  String get exportIcsText => 'ICS 텍스트 내보내기';

  @override
  String get exportJsonText => 'JSON 텍스트 내보내기';

  @override
  String get dataRestoredFromBackupNotice =>
      '기본 파일을 불러오지 못해 이전 백업에서 앱 데이터를 복원했습니다.';

  @override
  String get dataBackupRestoreFailedNotice =>
      '기본 데이터 파일과 백업이 모두 손상되었습니다. 앱이 새 상태로 실행됩니다.';

  @override
  String get dataRecoveryCorruptTitle => '데이터를 복구해야 합니다';

  @override
  String get dataRecoveryCorruptMessage =>
      '기본 데이터 파일과 백업을 읽지 못했습니다. 쓰기를 차단하기 전에 보호용 사본을 만들었습니다.';

  @override
  String get dataRecoveryIoFailureTitle => '저장소를 사용할 수 없습니다';

  @override
  String get dataRecoveryIoFailureMessage =>
      '현재 로컬 저장소에 접근할 수 없습니다. 저장소 접근 권한이나 기기 상태를 확인한 뒤 다시 시도하세요. 기존 데이터는 덮어쓰지 않습니다.';

  @override
  String get dataRecoveryUnsupportedVersionTitle => '이 데이터를 열려면 Sked를 업데이트하세요';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      '이 데이터는 더 최신 버전의 Sked에서 만들었습니다. 앱을 업데이트한 뒤 다시 시도하세요. 데이터를 보호하기 위해 새로 시작하기는 비활성화되어 있습니다.';

  @override
  String get dataRecoveryRetryAction => '다시 시도';

  @override
  String get dataRecoveryArtifactsHint =>
      '복구 파일이나 영향을 받은 저장 위치가 아래에 표시됩니다. 데이터를 복구할 때까지 파일을 변경하지 마세요.';

  @override
  String get dataRecoveryArtifactsAction => '복구 파일 및 위치 보기';

  @override
  String get dataRecoveryStartFreshAction => '새 데이터로 시작';

  @override
  String get dataRecoveryStartFreshConfirmTitle => '새 데이터로 시작할까요?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      '보호용 사본은 유지하지만 새 로컬 데이터 파일을 만듭니다. 먼저 복구를 다시 시도하지 않아도 되는 경우에만 계속하세요.';

  @override
  String get previousMonth => '이전 달';

  @override
  String get nextMonth => '다음 달';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String get reminderInProgress => '진행 중';

  @override
  String get deleteCourseTitle => '수업 삭제';

  @override
  String get deleteCourseMessage => '이 수업을 삭제할까요?';

  @override
  String get showLunarCalendar => '음력 표시';

  @override
  String monthDayEvents(int day, int count) {
    return '$day일, 일정 $count개';
  }

  @override
  String get defaultView => '기본 보기';

  @override
  String get generalDefaultViewSection => '시작 시';

  @override
  String get generalViewSwitchBehavior => '보기 전환 버튼';

  @override
  String get hideHomeWorkspaceNavigation => '작업 공간 탐색 숨기기';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      '작업 공간 탐색을 숨깁니다. 기본 화면의 작업 공간 메뉴에서 전환할 수 있습니다.';

  @override
  String get generalDateLabelFormat => '날짜 표시 형식';

  @override
  String get generalDateLabelFormatLocalized => '지역 형식 (2026년 7월)';

  @override
  String get generalDateLabelFormatSlash => '슬래시 구분 (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => '도구 모음 배치';

  @override
  String get toolbarNavigationSection => '도구 모음 탐색';

  @override
  String get toolbarNavigationHiddenBehavior => '숨긴 항목 처리';

  @override
  String get toolbarNavigationRemove => '완전히 숨기기';

  @override
  String get toolbarNavigationMore => '더보기로 이동';

  @override
  String get toolbarNavigationReorder => '도구 모음 항목 순서 변경';

  @override
  String get toolbarNavigationVisibility => '도구 모음 항목 표시';

  @override
  String get toolbarNavigationTimetable => '시간표 선택기';

  @override
  String get toolbarNavigationWeek => '주 선택기';

  @override
  String get toolbarNavigationView => '보기 전환';

  @override
  String get toolbarNavigationCategory => '카테고리 선택기';

  @override
  String get toolbarNavigationDate => '날짜 선택기';

  @override
  String get generalToolbarWidthPolicy => '도구 모음 공간 배분';

  @override
  String get generalToolbarWidthContent => '자동 배분';

  @override
  String get generalToolbarWidthBalanced => '균형 있게';

  @override
  String get generalToolbarWidthCalendarPriority => '카테고리 우선';

  @override
  String get generalToolbarWidthDatePriority => '날짜 우선';

  @override
  String get generalViewSwitchCycle => '보기를 순서대로 전환';

  @override
  String get generalViewSwitchMenu => '보기 메뉴 열기';

  @override
  String get generalViewSwitchTooltip => '보기 전환';

  @override
  String get generalViewSwitchMenuTooltip => '보기 선택';

  @override
  String get generalViewLongPressTodayHint => '길게 눌러 오늘로 이동';

  @override
  String get generalScheduleDisplaySection => '일정 표시';

  @override
  String get generalTimeGridSection => '시간 격자';

  @override
  String get generalPopupSection => '팝업 동작';

  @override
  String get quickActionsSection => '빠른 작업';

  @override
  String get showAddCourseFab => '떠 있는 수업 추가 버튼 표시';

  @override
  String get showAddCourseFabHint => '시간표 오른쪽 아래에 있는 수업 추가 버튼을 표시하거나 숨깁니다.';

  @override
  String get showAddEventFab => '떠 있는 일정 추가 버튼 표시';

  @override
  String get showAddEventFabHint => '일정 오른쪽 아래에 있는 일정 추가 버튼을 표시하거나 숨깁니다.';

  @override
  String get enableLongPressAddCourse => '빈 격자를 길게 눌러 수업 추가';

  @override
  String get enableLongPressAddCourseHint => '시간표 격자의 빈 곳을 길게 눌러 수업을 추가합니다.';

  @override
  String get enableLongPressAddEvent => '빈 격자를 길게 눌러 일정 추가';

  @override
  String get enableLongPressAddEventHint =>
      '일간 또는 주간 보기의 시간 격자에서 빈 곳을 길게 눌러 일정을 추가합니다.';

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
  String get developerNotificationDiagnostics => '알림 진단';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Android 알림 전달 상태를 확인하고, 기존 알림 계획을 다시 만들고, Sked의 일반 알림 서비스를 통해 안전한 테스트 알림을 보냅니다.';

  @override
  String get developerNotificationUnsupported =>
      '알림 진단은 Android에서만 사용할 수 있습니다.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      '일정 알림 관리가 시작된 후 알림 진단을 사용할 수 있습니다.';

  @override
  String get developerNotificationRefresh => '진단 새로고침';

  @override
  String get developerNotificationSystemStatus => '시스템 알림 권한';

  @override
  String get developerNotificationPermissionAllowed => '허용됨';

  @override
  String get developerNotificationPermissionBlocked => '차단됨';

  @override
  String get developerNotificationExactAlarm => '정확한 알람';

  @override
  String get developerNotificationExactAlarmAllowed => '허용됨';

  @override
  String get developerNotificationExactAlarmBlocked => '허용되지 않음';

  @override
  String get developerNotificationPlan => '일정 알림 계획';

  @override
  String get developerNotificationCoverage => '알림 예약 현황';

  @override
  String get developerNotificationCoverageReady =>
      '알려진 모든 유한 횟수 알림이 직접 예약되었습니다';

  @override
  String get developerNotificationCoverageRenewable =>
      '반복 알림은 가능한 범위에서 장기 재예약을 시도합니다';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      '직접 예약 한도에 도달했습니다. 이후 알림은 가능한 범위에서 재예약을 시도합니다';

  @override
  String get developerNotificationCoverageBlocked =>
      '정확한 전달에 필요한 조건을 충족하지 못했습니다';

  @override
  String get developerNotificationCoverageFailed => '최근 알림 동기화에 실패했습니다';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '직접 예약 $scheduled개 / 한도 $capacity개';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return '마지막 오류: $message';
  }

  @override
  String get developerNotificationTestChannel => '테스트 채널';

  @override
  String get developerNotificationTestCourse => '수업 알림';

  @override
  String get developerNotificationTestSchedule => '일정 알림';

  @override
  String get developerNotificationImmediateTest => '즉시 테스트 알림 보내기';

  @override
  String get developerNotificationThirtySecondTest => '30초 후 백그라운드 테스트 예약';

  @override
  String get developerNotificationImmediateQueued => '즉시 테스트 알림을 보냈습니다.';

  @override
  String get developerNotificationThirtySecondQueued =>
      '30초 후 백그라운드 테스트를 예약했습니다.';

  @override
  String get developerNotificationAppSwitch => '앱 알림 스위치';

  @override
  String get developerNotificationAppSwitchEnabled => '일반 알림이 활성화되었습니다';

  @override
  String get developerNotificationAppSwitchDisabled =>
      '일반 알림이 비활성화되었습니다. 개발자 테스트는 실행할 수 있습니다';

  @override
  String get developerNotificationTimeZone => '현지 시간대';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      '아직 생성되지 않았습니다. 개발자 테스트를 실행하면 생성됩니다.';

  @override
  String get developerNotificationChannelEnabledState => '활성화됨';

  @override
  String get developerNotificationChannelBlockedState => '차단됨';

  @override
  String developerNotificationChannelImportance(int importance) {
    return '중요도: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      '중요도를 확인할 수 없음';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '대기 중 $pending개 / 표시 중 $active개';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return '네이티브 알림 마지막 표시: $time';
  }

  @override
  String get developerNotificationNoDiagnostic => '아직 재조정 기록이 없습니다.';

  @override
  String get developerNotificationNextReminder => '다음 실제 알림';

  @override
  String get developerNotificationNoPendingReminder => '현재 계획에 예정된 알림이 없습니다';

  @override
  String get developerNotificationNextRenewal => '다음 재예약 시도';

  @override
  String get developerNotificationLastSynchronization => '최근 알림 동기화';

  @override
  String get developerNotificationLateRecovery => '늦은 알림 복구';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '원래 시각이 지난 알림 $count개를 복구하여 전달했습니다';
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
  String get developerNotificationReconcileOriginForeground => '포그라운드';

  @override
  String get developerNotificationReconcileOriginBackground => '백그라운드';

  @override
  String get developerNotificationReconcileModeAuthoritative => '전체 재계산';

  @override
  String get developerNotificationReconcileModeRecovery => '복구';

  @override
  String get developerNotificationRunRecovery => '알림 복구 실행';

  @override
  String get developerNotificationRecoveryComplete => '알림 복구가 완료되었습니다';

  @override
  String get developerNotificationReconcileResultSuccess => '성공';

  @override
  String get developerNotificationReconcileResultSkipped => '건너뜀';

  @override
  String get developerNotificationReconcileResultBlocked =>
      '정확한 전달 조건을 모두 충족할 때까지 차단됨';

  @override
  String get developerNotificationReconcileResultFailed => '실패';

  @override
  String get developerNotificationBackgroundLimits => '제조사 백그라운드 제한';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      '제조사의 백그라운드 제한이 알림 전달에 영향을 줄 수 있습니다.';

  @override
  String get developerNotificationAutostart => '제조사 백그라운드 시작';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return '제조사: $vendor. 제조사 설정을 열 수 있습니다. Android에서는 해당 허용 상태를 확인할 수 없습니다.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return '제조사: $vendor. 대신 앱 상세 정보를 엽니다. Android에서는 해당 허용 상태를 확인할 수 없습니다.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      '열 수 있는 제조사 백그라운드 설정이 없습니다.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return '마지막으로 연 대상: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor => '제조사 설정';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      '앱 상세 정보';

  @override
  String get developerNotificationAutostartTargetUnavailable => '없음';

  @override
  String get developerNotificationRebootBoundaryTitle => '재부팅 후 복구 조건';

  @override
  String get developerNotificationRebootBoundary =>
      '처음 잠금을 해제한 뒤 복구가 시작됩니다. 강제 종료된 앱은 스스로 시작할 수 없습니다.';

  @override
  String get developerNotificationTestChecking =>
      '알림 상태를 확인하는 동안에는 테스트할 수 없습니다.';

  @override
  String get developerNotificationTestBlockedSystem =>
      '시스템 알림이 차단되어 테스트할 수 없습니다.';

  @override
  String get developerNotificationTestBlockedChannel =>
      '선택한 알림 채널이 차단되어 테스트할 수 없습니다.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Windows 알림 설정에서 관리됨';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Windows에서는 해당 없음';

  @override
  String get developerNotificationWindowsIdentity => 'Windows 패키지 ID';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX ID가 있어 표시 중인 알림을 취소할 수 있습니다';

  @override
  String get developerNotificationWindowsMsixRequired =>
      '표시 중인 알림을 확실히 취소하려면 MSIX 버전을 설치하세요';

  @override
  String get collapseWorkspaceNavigation => '작업 공간 탐색 접기';

  @override
  String get expandWorkspaceNavigation => '작업 공간 탐색 펼치기';

  @override
  String get schoolWebImportExitBrowser => '앱 내 브라우저 종료';

  @override
  String get schoolWebImportEditAddress => '주소 수정';

  @override
  String get schoolWebImportAddressLabel => '웹 주소';

  @override
  String get schoolWebImportOpenAddress => '열기';

  @override
  String get schoolWebImportAddressInvalid =>
      '호스트가 포함된 HTTP 또는 HTTPS 주소를 입력하세요.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      '이 웹페이지에서 이 기기에서 열 수 없는 새 창을 요청했습니다.';

  @override
  String get schoolWebImportSecureConnection => '보안 연결';

  @override
  String get schoolWebImportInsecureConnection => '안전하지 않은 연결';

  @override
  String get notificationSettingsSection => '미리 알림 및 알림';

  @override
  String get notificationCoverage => '알림 예약 현황';

  @override
  String get notificationCoverageBlocked =>
      'Reminders are blocked and will not fire. Review the system requirements below.';

  @override
  String get notificationCoverageFailed =>
      'Reminders could not be synced. Open notification settings and try again.';

  @override
  String get notificationCoverageRenewable =>
      '종료일이 없는 반복 일정은 백그라운드에서 재예약하여 장기적으로 알림을 유지합니다.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android는 알림을 최대 $capacity개까지 직접 예약할 수 있습니다. 이후 알림은 미리 재예약을 시도합니다.';
  }

  @override
  String get notificationSettingsEnabled => '미리 알림 및 알림 사용';

  @override
  String get notificationSettingsEnabledHint =>
      '미리 알림이 설정된 항목만 예약합니다. 기본값을 사용하는 수업은 아래에서 수업 기본 알림을 설정하세요.';

  @override
  String get notificationPrecisionLimitations =>
      '알림은 시스템 권한과 백그라운드 실행에 영향을 받습니다. 전원 종료, 시간 변경 또는 시스템 제한으로 지연될 수 있습니다.';

  @override
  String get notificationSettingsEnabledSummary => '활성화됨';

  @override
  String get notificationSettingsDisabledSummary => '비활성화됨';

  @override
  String get notificationDefaultsSection => '기본 미리 알림';

  @override
  String get notificationCourseDefaultReminder => '수업 기본 미리 알림';

  @override
  String get notificationGeneralDefaultReminder => '일정 기본 미리 알림';

  @override
  String get notificationReminderOff => '알림 없음';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes분 전';
  }

  @override
  String get notificationPermission => '알림 권한';

  @override
  String get notificationPermissionGranted => '시스템에서 허용됨';

  @override
  String get notificationPermissionDenied => '시스템에서 차단됨';

  @override
  String get notificationPermissionChecking => '권한 확인 중…';

  @override
  String get notificationPermissionRequest => '권한 요청';

  @override
  String get notificationPermissionOpenSettings => '시스템 설정 열기';

  @override
  String get notificationPermissionRequestFailed =>
      '알림 권한을 확인하지 못했습니다. 다시 시도하세요.';

  @override
  String get notificationExactAlarm => '정확한 알람 권한';

  @override
  String get notificationExactAlarmAllowed => '시스템에서 허용됨';

  @override
  String get notificationExactAlarmRequired => '정확한 시각의 알림에 필요합니다';

  @override
  String get notificationExactAlarmRequest => '정확한 알람 허용';

  @override
  String get notificationBatteryOptimization => '배터리 최적화';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Android 배터리 최적화 제외 목록에 등록됨';

  @override
  String get notificationBatteryOptimizationWarning =>
      'Battery optimization or vendor background restrictions may delay reminders. You can adjust these in system settings.';

  @override
  String get notificationBatteryOptimizationRequest => '배터리 최적화 설정 열기';

  @override
  String get notificationAutostart => '제조사 백그라운드 시작';

  @override
  String get notificationAutostartVendorHint =>
      '재부팅 후 알림을 복구할 수 있도록 자동 시작 또는 백그라운드 실행을 허용하세요.';

  @override
  String get notificationAutostartFallbackHint =>
      'Sked 앱 상세 정보에서 백그라운드 실행을 허용하세요. Android에서는 이 제조사 설정을 확인할 수 없습니다.';

  @override
  String get notificationAutostartUnavailable =>
      '제조사 설정 페이지를 찾지 못했습니다. Sked 앱 상세 정보를 직접 확인하세요.';

  @override
  String get notificationAutostartRequest => '제조사 백그라운드 설정 열기';

  @override
  String get notificationAutostartOpenFailed =>
      '제조사 백그라운드 설정을 열지 못했습니다. Sked 앱 상세 정보를 직접 확인하세요.';

  @override
  String get notificationLockScreenTitles => '알림에 제목 표시';

  @override
  String get notificationLockScreenTitlesHint =>
      '잠금 화면에도 적용됩니다. 끄면 알림에 유형과 시간만 포함됩니다.';

  @override
  String get notificationPlatformUnsupported => '이 플랫폼은 네이티브 알림을 제공하지 않습니다.';

  @override
  String get workspaceFeatures => '기능 관리';

  @override
  String get workspaceBoth => '시간표 및 일정';

  @override
  String get workspaceOnlyStudent => '시간표만';

  @override
  String get workspaceOnlyGeneral => '일정만';

  @override
  String get workspaceDisableTitle => '이 작업 공간을 비활성화할까요?';

  @override
  String get workspaceDisableMessage =>
      '데이터와 설정은 유지됩니다. 여기서 다시 활성화할 때까지 관련 기능과 알림이 중지됩니다.';

  @override
  String get workspaceEnableHint => '사용할 기능을 선택하세요. 하나 이상은 활성화해야 합니다.';

  @override
  String get workspaceLastRequired => '하나 이상의 작업 공간을 활성화해야 합니다.';

  @override
  String get workspaceReminderCleanupFailed =>
      '작업 공간은 비활성화되었지만 알림 정리가 완료되지 않았습니다. 알림 복구를 다시 시도하세요.';

  @override
  String get settingsDataPrivacy => '데이터 및 개인정보';

  @override
  String get selectedDayAgenda => '선택한 날짜의 일정';

  @override
  String get notificationTroubleshooting => '권한 및 문제 해결';

  @override
  String get settingsConnection => '연결';

  @override
  String get settingsAdvanced => '고급';

  @override
  String get unsavedChangesMessage => '저장하지 않은 변경사항이 있습니다. 버리고 나갈까요?';

  @override
  String get backupWorkspaceSelection => '전체 백업에는 데이터와 활성화된 작업 공간 설정이 포함됩니다.';

  @override
  String get assistantLayoutPreview => 'AI · 레이아웃 미리보기';

  @override
  String get assistantSelectionContext => '현재 선택한 항목을 맥락으로 사용합니다';

  @override
  String get assistantPreviewDescription =>
      'Discuss and work in the current workspace. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => '메시지 초안';

  @override
  String get assistantPreviewNoSend => '레이아웃 미리보기 전용입니다. 전송하거나 변경하지 않습니다.';

  @override
  String get resizePanel => '패널 크기 조절';

  @override
  String get minimizeWindow => '최소화';

  @override
  String get maximizeWindow => '최대화';

  @override
  String get restoreWindow => '이전 창 크기로 복원';

  @override
  String get closeWindow => '창 닫기';

  @override
  String get courseSystemReminder => '시스템 알림';

  @override
  String courseReminderInherit(String reminder) {
    return '기본값 사용 ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      '알림 설정에서 시스템 알림이 꺼져 있습니다. 이 수업의 알림 설정은 저장할 수 있습니다.';

  @override
  String get courseReminderDefaultOff =>
      '수업 기본 알림이 설정되지 않았습니다. 여기서 직접 선택하거나 알림 설정에서 기본값을 설정하세요.';

  @override
  String get courseReminderDeliveryHint =>
      '이 설정은 수업과 함께 저장됩니다. 실제 전달 여부는 시스템 알림 권한과 백그라운드 제한에 따라 달라집니다.';

  @override
  String get courseReminderPermissionUnknown =>
      '시스템 알림 상태를 아직 확인하지 않았습니다. 알림에 의존하기 전에 알림 설정을 검토하세요.';

  @override
  String get courseReminderMinutesLabel => '수업 시작 몇 분 전';

  @override
  String get exportAction => '내보내기';

  @override
  String get datePickerSelectWeek => '주 선택';

  @override
  String get datePickerSelectMonth => '월 선택';

  @override
  String get generalDateLabelFormatDescription => '데스크톱과 작은 화면의 날짜 탐색에 적용됩니다.';

  @override
  String get dateRangeTitle => '날짜 범위 선택';

  @override
  String get dateRangeCustom => '사용자 지정';

  @override
  String get dateRangeChooseStart => '시작 날짜를 선택하세요';

  @override
  String get dateRangeChooseEnd => '종료 날짜를 선택하세요';

  @override
  String get dateRangeLimit => '시작일과 종료일을 포함하여 1~14일을 선택하세요.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days일',
      one: '1일',
    );
    return '사용자 지정 · $_temp0';
  }

  @override
  String get timePickerWheelMode => '휠로 선택';

  @override
  String get courseReminderUseDefault => '기본값 사용';

  @override
  String get courseReminderInvalidMinutes => '0 이상의 정수로 분 수를 입력하세요.';

  @override
  String get generalCustomColumnWidth => '사용자 지정 보기 열 너비';

  @override
  String get generalCustomColumnWidthAuto => '자동';

  @override
  String get generalCustomColumnWidthManual => '최소 너비';

  @override
  String get generalCustomColumnWidthMinimum => '날짜별 최소 너비';

  @override
  String get generalCustomColumnWidthHint =>
      '모든 날짜에 같은 최소 너비를 적용합니다. 공간이 있으면 열을 고르게 채우고 부족하면 가로로 스크롤합니다. 사용자 지정 보기에만 적용됩니다.';

  @override
  String get settingsAppearanceLanguage => '화면 모양 및 언어';

  @override
  String get settingsAppearanceDetails => '색상 및 윤곽선';

  @override
  String get monthNoEvents => '이 날짜에는 일정이 없습니다';

  @override
  String get settingsOverview => '개요';

  @override
  String get settingsThemeTarget => '테마 적용 대상';

  @override
  String get settingsColorMode => '색상 모드';

  @override
  String get settingsNotificationPreferences => '알림 설정';

  @override
  String get settingsNotificationPreferencesSummary => '기본 미리 알림, 권한 및 안정성';

  @override
  String get settingsFeaturesSummary => '작업 공간 및 탐색';

  @override
  String get settingsPrivacySummary => '개인정보 처리방침 및 로컬 데이터 삭제';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count교시',
      one: '1교시',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => '교시';

  @override
  String get periodTimesDurationColumn => '시간 길이';

  @override
  String get periodTimesGapColumn => '쉬는 시간';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes분';
  }

  @override
  String get periodTimesSavePending => '저장 대기 중…';

  @override
  String get periodTimesSaveFailed => '저장되지 않음 · 저장 실패';

  @override
  String get periodTimesInvalidStatus => '저장되지 않음 · 강조된 시간을 수정하세요';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      '마지막 저장이 취소되었는지 확인할 수 없습니다. 쓰기를 중지하고 복구 사본을 보존했습니다. 저장소 상태를 확인한 후 다시 불러오세요.';

  @override
  String get settingsPanelDisplayMode => '패널 표시 방식';

  @override
  String get settingsPanelDisplayModeGlobal => '시간표와 일정에 공통 적용';

  @override
  String get settingsPanelDisplayOverlay => '겹쳐 표시';

  @override
  String get settingsPanelDisplaySideBySide => '나란히 표시';

  @override
  String get settingsPanelDisplayAutomatic => '자동';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      '달력 크기를 바꾸지 않고 오른쪽에 겹쳐 표시합니다.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      '나란히 표시를 우선하며 달력이 너무 좁아질 때만 겹쳐 표시합니다.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      '달력을 읽기 충분한 너비가 있으면 나란히, 그렇지 않으면 겹쳐 표시합니다.';

  @override
  String get toolbarNavigationEssentialHint =>
      '도구 모음에서 설정이나 작업 공간을 끄면 삭제되지 않고 더보기로 이동합니다. 필수 작업이 들어 있는 동안에는 더보기를 숨길 수 없습니다. 작업 공간 전환은 하단 탐색이 숨겨져 있고 여러 작업 공간이 활성화된 경우에만 표시됩니다.';

  @override
  String get reminderEnded => '종료됨';

  @override
  String get reminderAutoCloseHint => '10초 후 닫힙니다. 패널을 조작하면 열린 상태로 유지됩니다.';

  @override
  String get showReminderIndependently => '독립적으로 열기';

  @override
  String get categoryManagerTitle => '카테고리 관리';

  @override
  String get categoryHidden => '숨김';

  @override
  String get categoryShowOnCalendar => '캘린더에 표시';

  @override
  String get categoryHideOnCalendar => '캘린더에서 숨기기';

  @override
  String get categoryEditColor => '카테고리 색상 변경';

  @override
  String get categoryThemePalette => '테마 팔레트';

  @override
  String get categoryCustomColor => '사용자 지정';

  @override
  String get colorHexInvalid => '6자리 16진수 색상 코드를 입력하세요.';

  @override
  String get colorPickerHue => '색조';

  @override
  String get colorPickerSaturation => '채도';

  @override
  String get colorPickerValue => '명도';

  @override
  String get colorPickerHex => '16진수 색상';

  @override
  String get colorPickerSpectrum => '색상 스펙트럼';

  @override
  String get colorPickerSpectrumKeyboardHint =>
      '왼쪽과 오른쪽 화살표로 채도를, 위쪽과 아래쪽 화살표로 명도를 조절하세요.';

  @override
  String categoryColorSlot(int number) {
    return '테마 색상 $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      '스토어 업데이트가 늦게 제공될 수 있습니다. 제공 여부는 스토어 페이지에서 확인하세요.';

  @override
  String get storePrereleaseNotice =>
      '시험판 업데이트 알림을 받아도 스토어 테스트 프로그램에 자동으로 등록되지는 않습니다.';

  @override
  String get updateFoundTitle => '새 버전이 있습니다';

  @override
  String get updateNoNotes => '제공된 릴리스 정보가 없습니다.';

  @override
  String get updateLater => '나중에';

  @override
  String get updateRetry => '다시 시도';

  @override
  String get updatePrerelease => '시험판';

  @override
  String get updateNetworkFailure => '업데이트를 확인하지 못했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String updateNoNewerVersion(String version) {
    return '새 버전이 없습니다 (현재: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => '백업 복원 중…';

  @override
  String get backupRestoreInProgressMessage =>
      '복원이 완료되면 데이터와 설정을 변경할 수 있습니다. 내용은 계속 볼 수 있습니다.';

  @override
  String get managePeriodTimeSets => '교시 시간 세트 관리';

  @override
  String periodTimeSetUsageSummary(int periodCount, int timetableCount) {
    return '교시 $periodCount개 · 사용 중인 시간표 $timetableCount개';
  }

  @override
  String chooseTimetableImportMethod(String name) {
    return '새 시간표로 가져오거나 “$name”의 시간표 정보와 수업을 모두 바꿉니다.';
  }

  @override
  String get selectAtLeastOneWeek => '주차를 하나 이상 선택하세요.';

  @override
  String get notificationRemindHiddenGeneralCalendars => '숨겨진 카테고리의 알림 유지';

  @override
  String get notificationRemindHiddenGeneralCalendarsHint =>
      '앱 내 알림과 시스템 알림에 적용됩니다. 시스템 알림을 받으려면 알림 설정도 켜져 있어야 합니다.';

  @override
  String get generalReminderFollowDefault => '기본값 사용';

  @override
  String get generalReminderCustom => '사용자 지정 알림';

  @override
  String get eventEditScopeTitle => '반복 일정 편집';

  @override
  String get eventEditThisOccurrence => '이번 일정만';

  @override
  String get eventEditThisAndFollowing => '이번 일정 및 이후 일정';

  @override
  String get eventEditEntireSeries => '전체 반복 일정';

  @override
  String get eventEditEntireSeriesHint => '지난 일정을 포함한 전체 반복 일정에 변경 사항이 적용됩니다.';

  @override
  String get eventEditConflict =>
      '이 일정이 변경되었습니다. 작성 중인 내용은 유지됩니다. 일정을 다시 열어 최신 내용을 확인하세요.';

  @override
  String eventSavedToHiddenCalendar(String name) {
    return '숨겨진 카테고리 “$name”에 저장했습니다.';
  }

  @override
  String get viewEvent => '일정 보기';

  @override
  String get schoolSitesNameRequired => '학교 이름을 입력하세요.';

  @override
  String get schoolSitesLoginUrlRequired => '로그인 URL을 입력하세요.';

  @override
  String get languageNoResults => '일치하는 언어가 없습니다';

  @override
  String get themeGeneralMonthTextColors => '월 보기 텍스트';

  @override
  String get themeGeneralFestivalTextColor => '기념일 및 공휴일';

  @override
  String get themeGeneralSolarTermTextColor => '절기';

  @override
  String get themeGeneralLunarTextColor => '음력 날짜';

  @override
  String get courseTextLowContrastHint =>
      '이 글자색은 일부 수업 카드에서 읽기 어려울 수 있습니다(명암비 4.5:1 미만). 그대로 유지하거나 다른 색을 선택할 수 있습니다.';

  @override
  String get shortenSemesterTitle => '학기를 줄일까요?';

  @override
  String shortenSemesterMessage(int weeks, int count) {
    return '학기가 $weeks주에 끝납니다. 이후 수업이 있는 과목: $count개. 과목과 선택한 주차는 유지됩니다. 주 수를 복원하면 다시 볼 수 있습니다.';
  }

  @override
  String get defaultGeneralCalendarName => '내 캘린더';

  @override
  String get icsImportReportTitle => '가져오기 보고서';

  @override
  String get icsImportReportAction => '보고서 보기';

  @override
  String get icsExportFailureTitle => 'ICS로 내보낼 수 없음';

  @override
  String get icsCopyDiagnosticsAction => '세부 정보 복사';

  @override
  String get icsUnsupportedTimeZoneMessage =>
      '이 ICS에는 Sked가 안전하게 해석할 수 없는 이름이 지정된 시간대가 있습니다. 아무것도 가져오지 않았습니다. 원본 캘린더에서 UTC 또는 시간대 없는 현지 시간으로 내보낸 후 다시 시도하세요.';

  @override
  String get icsExportMonthlyAnchorMismatchMessage =>
      '이 월간 일정은 ICS로 정확하게 표현할 수 없습니다. 날짜를 보존하려면 JSON으로 내보내세요.';

  @override
  String get icsExportEmptyRecurrenceMessage =>
      '이 반복 일정에는 ICS로 내보낼 유효한 일정이 없습니다. 기록을 보존하려면 JSON으로 내보내세요.';

  @override
  String get icsImportedCalendarName => '가져온 캘린더';

  @override
  String get icsUntitledEventName => '제목 없는 일정';

  @override
  String notificationWindowsCoverageLimit(int days, int capacity) {
    return 'Windows는 앞으로 $days일 이내의 알림을 한 번에 최대 $capacity개까지 예약합니다. 정기적으로 앱을 다시 열어 계획을 갱신하세요.';
  }

  @override
  String notificationWindowsCoverageSummary(int count, String date) {
    return '예약된 알림: $count개. 마지막 확인 범위는 $date까지입니다.';
  }

  @override
  String get notificationWindowsCoverageCapacityLimited =>
      '알림 개수 제한에 도달해 일부 알림이 아직 예약되지 않았습니다. 예정된 알림이 실행된 후 앱을 다시 열어 계획을 갱신하세요.';

  @override
  String get courseInactiveThisWeek => '이번 주 수업 없음';

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
  String get notificationSnoozeAction => '10분 후 다시 알림';

  @override
  String get notificationHandledAction => '처리됨으로 표시';

  @override
  String get developerTestNotificationTitle => 'Sked 알림 테스트';

  @override
  String get developerTestNotificationCourseBody => '수업 알림 채널이 정상적으로 작동합니다.';

  @override
  String get developerTestNotificationScheduleBody => '일정 알림 채널이 정상적으로 작동합니다.';

  @override
  String get eventRecurrenceExceptionsChangeTitle => 'Change repeat pattern?';

  @override
  String get eventRecurrenceExceptionsChangeMessage =>
      'Previously skipped dates stay skipped only if the new repeat pattern still has an occurrence on that date. Other skip records will be removed. Turning repeats off removes all skip records. Events edited separately stay unchanged.';
}
