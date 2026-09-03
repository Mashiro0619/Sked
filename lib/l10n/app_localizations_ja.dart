// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return '第$week週';
  }

  @override
  String get addCourse => '授業を追加';

  @override
  String get settings => '設定';

  @override
  String get multiTimetableSwitch => '時間割を切り替え';

  @override
  String currentTimetableWeeks(int weeks) {
    return '現在の時間割 · $weeks週';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'タップして切り替え · $weeks週';
  }

  @override
  String get editTimetable => '時間割を編集';

  @override
  String get schoolImportResultEditorTitle => '解析結果を編集';

  @override
  String get schoolImportParsePageTitle => '時間割を解析';

  @override
  String get schoolImportParsePageParsing => '解析中…';

  @override
  String get schoolImportParsePageFailed => '解析に失敗';

  @override
  String get schoolImportParsePageComplete => '解析完了';

  @override
  String get schoolImportParsePageContinue => '続行';

  @override
  String get schoolImportParsePageRawContent => '生の応答';

  @override
  String get schoolImportParsePageExpandRaw => '生の応答を展開';

  @override
  String get schoolImportParsePageCollapseRaw => '生の応答を折りたたむ';

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
  String get createTimetable => '新しい時間割';

  @override
  String get jumpToWeek => '週へ移動';

  @override
  String get timetable => '時間割';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => '時間割名';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => '総週数';

  @override
  String get delete => '削除';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get deleteTimetableTitle => '時間割を削除';

  @override
  String deleteTimetableMessage(Object name) {
    return '\"$name\"を削除しますか？';
  }

  @override
  String get noTimetableTitle => '時間割がありません';

  @override
  String get noTimetableMessage => '時間割を作成するか、JSONファイルからインポートしてください。';

  @override
  String get importTimetable => '時間割をインポート';

  @override
  String get courseName => '授業名';

  @override
  String get location => '場所';

  @override
  String get dayOfWeek => '曜日';

  @override
  String get semesterWeeks => '週';

  @override
  String get startTime => '開始時刻';

  @override
  String get endTime => '終了時刻';

  @override
  String get linkedPeriods => '連携時限';

  @override
  String get linkedPeriodsUnmatched => '現在の時刻に一致する時限がありません。手動で選択してください。';

  @override
  String periodRangeLabel(int start, int end) {
    return '$start〜$end限';
  }

  @override
  String get teacherName => '担当教員';

  @override
  String get credits => '単位数';

  @override
  String get remarks => '備考';

  @override
  String get customFields => 'カスタム項目';

  @override
  String get customFieldsHint => '1行に1件、形式: key:value';

  @override
  String get more => 'その他';

  @override
  String get selectDayOfWeek => '曜日を選択';

  @override
  String get selectSemesterWeeks => '週を選択';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get clear => 'クリア';

  @override
  String get confirm => '確認';

  @override
  String get selectLinkedPeriods => '連携時限を選択';

  @override
  String get addCourseTitle => '授業を追加';

  @override
  String get editCourseTitle => '授業を編集';

  @override
  String get editCourseTooltip => '授業を編集';

  @override
  String get place => '場所';

  @override
  String get time => '時間';

  @override
  String get notFilled => '未入力';

  @override
  String get none => 'なし';

  @override
  String get conflictCourses => '重複している授業';

  @override
  String get locationNotFilled => '場所が未入力です';

  @override
  String get setAsDisplayed => '表示中として設定';

  @override
  String get editThisCourse => 'この授業を編集';

  @override
  String get settingsTitle => '設定';

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
  String get noTimetableSettings => '設定できる時間割が現在ありません。';

  @override
  String get semesterStartDate => '学期開始日';

  @override
  String get periodTimeSets => '時限時間セット';

  @override
  String get noPeriodTimeAvailable => '利用可能な時限時間セットがありません';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count時限';
  }

  @override
  String get coursePopupDismissSetting => '外側をタップして授業ポップアップを閉じる';

  @override
  String get coursePopupDismissSettingHint => 'オフにすると、下にスワイプして閉じる操作も無効になります。';

  @override
  String get preserveTimetableGaps => '時間割の空き時間を保持';

  @override
  String get preserveTimetableGapsHint =>
      'オフにすると、昼休みや休憩の空白が詰められ、後ろの授業が上に移動します。';

  @override
  String get showPastEndedCourses => '終了済みの授業を表示';

  @override
  String get showPastEndedCoursesHint => '実際の現在週ですでに終了している授業を、より薄いグレーで表示します。';

  @override
  String get showFutureCourses => '今後の授業を表示';

  @override
  String get showFutureCoursesHint => '今週は開講していないが後の週に表示される授業を、グレーで表示します。';

  @override
  String get timetableDisplaySettings => '時間割の表示と操作';

  @override
  String get timetableDisplaySettingsDesc => '授業表示、レイアウト、週切り替えジェスチャー、クイック追加';

  @override
  String get showTimetableGridLines => '時間割のグリッド線を表示';

  @override
  String get showTimetableGridLinesHint => '時間割の横線・縦線を表示するかどうかを設定します。';

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
  String get liveCourseOutlineColor => '授業の枠線色';

  @override
  String get liveCourseOutlineColorHint =>
      '枠線の対象を現在/次の授業にするか、このページに表示中のすべての授業にするかを選びます。';

  @override
  String get liveCourseOutlineSettings => '授業の枠線';

  @override
  String get liveCourseOutlineSettingsHint =>
      '枠線を有効にするか、対象、テーマ色に合わせるか、実際の枠線色を設定します。';

  @override
  String get liveCourseOutlineEnabled => '枠線を有効化';

  @override
  String get liveCourseOutlineFollowTheme => 'テーマ色に合わせる';

  @override
  String get liveCourseOutlineTarget => '枠線の対象';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => '現在/次の授業';

  @override
  String get liveCourseOutlineTargetAllDisplayed => '表示中のすべての授業';

  @override
  String get liveCourseOutlineEffectiveColor => '適用中の色';

  @override
  String get liveCourseOutlineCustomColor => 'カスタム枠線色';

  @override
  String get liveCourseOutlineWidth => '枠線の太さ';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => '言語';

  @override
  String get languagePageDescription => 'アプリで実際に利用できる言語を選択してください。';

  @override
  String get languageChinese => '中国語';

  @override
  String get languageEnglish => '英語';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'APIレスポンス';

  @override
  String get theme => 'テーマ';

  @override
  String get themeFollowSystem => 'システムに合わせる';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeColor => 'テーマカラー';

  @override
  String get themeColorModeSingle => '単色テーマカラー';

  @override
  String get themeColorModeColorful => 'カラフル';

  @override
  String get themeColorUiColors => 'UIカラー';

  @override
  String get themeColorCourseColors => '授業カラー';

  @override
  String get themeColorPrimary => 'プライマリ';

  @override
  String get themeColorSecondary => 'セカンダリ';

  @override
  String get themeColorTertiary => 'ターシャリ';

  @override
  String get themeColorCourseText => '授業テキスト';

  @override
  String get themeColorCourseTextAuto => '自動';

  @override
  String get themeColorCourseTextCustom => 'カスタム色';

  @override
  String get themeColorCourseColorsEmpty => '時間割をインポートすると授業カラーが生成されます。';

  @override
  String get themeCustomColor => 'カスタム色';

  @override
  String get themeApplyCustomColor => '色を適用';

  @override
  String get themeApplySettings => '設定を適用';

  @override
  String get dataImportExport => 'データのインポートとエクスポート';

  @override
  String get dataImportExportDesc =>
      '全データまたは単一の時間割をインポート、または現在/すべての時間割をエクスポートします。';

  @override
  String get appBackupTitle => 'アプリのバックアップと復元';

  @override
  String get appBackupSubtitle =>
      '時間割、予定、設定、学校サイトをバックアップまたは復元します。API キーは含まれません。';

  @override
  String get appBackupSheetSubtitle =>
      '完全復元では現在のアプリデータが置き換えられます。AI API キーは安全なストレージに保存され、バックアップファイルには書き込まれません。';

  @override
  String get restoreBackupFileTitle => 'JSON ファイルから復元';

  @override
  String get restoreBackupFileSubtitle =>
      'Sked の完全バックアップファイルを選択します。復元前に確認があります。';

  @override
  String get restoreBackupTextTitle => 'バックアップ JSON を貼り付け';

  @override
  String get restoreBackupTextSubtitle => '完全バックアップを貼り付けて、現在のアプリデータを復元します。';

  @override
  String get shareBackupTitle => 'バックアップファイルを共有';

  @override
  String get shareBackupSubtitle =>
      'アプリの全データを JSON としてエクスポートします。API キーは除外されます。';

  @override
  String get saveBackupTitle => 'バックアップファイルを保存';

  @override
  String get saveBackupSubtitle => 'アプリの完全バックアップをローカルファイルに保存します。';

  @override
  String get copyBackupTitle => 'バックアップテキストをコピー';

  @override
  String get copyBackupSubtitle => '完全なバックアップ JSON を表示し、コピーまたは一時保存できるようにします。';

  @override
  String get restoreBackupConfirmTitle => '完全バックアップを復元しますか？';

  @override
  String get restoreBackupConfirmMessage =>
      '現在のすべての時間割、一般予定、設定、学校サイトが置き換えられます。API キーはバックアップからインポートされません。時間割を再度解析する前にキーを再入力してください。';

  @override
  String get restoreBackupConfirmAction => 'バックアップを復元';

  @override
  String get restoreBackupSuccessMessage =>
      'アプリの完全バックアップを復元しました。AI API キーを再入力する必要があります。';

  @override
  String get restoreBackupFailureMessage =>
      '復元に失敗しました。バックアップ内容を確認して、もう一度お試しください。';

  @override
  String get openSourceLicenses => 'オープンソースライセンス';

  @override
  String get openSourceLicensesDesc => 'Flutter依存関係と同梱アプリアイコン素材のライセンスを表示します。';

  @override
  String get checkForUpdates => 'アップデートを確認';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'すでに最新バージョンです ($version)';
  }

  @override
  String get currentVersionLabel => '現在のバージョン';

  @override
  String get newVersionAvailable => 'アップデートがあります';

  @override
  String get latestVersionLabel => '最新バージョン';

  @override
  String get updateContentLabel => '更新内容';

  @override
  String get officialWebsite => '公式サイト';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'クラウドドライブ';

  @override
  String get ignoreThisVersion => 'このバージョンを無視';

  @override
  String get openUpdatesFailed => 'アップデートリンクを開けませんでした';

  @override
  String get updateCheckFailedTitle => 'アップデート確認に失敗しました';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'GitHubリポジトリ';

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
  String get openGithubFailed => 'GitHubリポジトリのリンクを開けませんでした';

  @override
  String get openPrivacyPolicyFailed => 'プライバシーポリシーのリンクを開けませんでした';

  @override
  String get selectPeriodTimeSet => '時限時間セットを選択';

  @override
  String get newItem => '新規';

  @override
  String get editPeriodTimeSet => '時限時間セットを編集';

  @override
  String get importTimetableFiles => '時間割をインポート';

  @override
  String get importTimetableFilesDesc => '1つまたは複数の時間割ファイルに対応しています。';

  @override
  String get importTimetableText => 'テキストから時間割をインポート';

  @override
  String get importTimetableTextDesc => '時間割JSONの内容を貼り付けてインポートします。';

  @override
  String get shareTimetableFiles => '時間割ファイルを共有';

  @override
  String get shareTimetableFilesDesc => '先に1つ以上の時間割を選択してください。';

  @override
  String get saveTimetableFiles => '時間割ファイルを保存';

  @override
  String get saveTimetableFilesDesc => '先に1つ以上の時間割を選択してください。';

  @override
  String get exportTimetableText => '時間割をテキストでエクスポート';

  @override
  String get exportTimetableTextDesc => '1つ以上の時間割を選択してから、JSON内容をコピーします。';

  @override
  String get jsonContent => 'JSON内容';

  @override
  String get pasteJsonContentHint => 'インポートするJSON内容を貼り付けてください。';

  @override
  String get jsonContentEmpty => '先にJSON内容を貼り付けてください。';

  @override
  String get copyText => 'コピー';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get share => '共有';

  @override
  String get selectTimetablesToExport => 'エクスポートする時間割を選択';

  @override
  String get selectTimetablesToImport => 'インポートする時間割を選択';

  @override
  String timetableCourseCount(int count) {
    return '$count件の授業';
  }

  @override
  String get importAction => 'インポート';

  @override
  String get importTimetableDialogTitle => '時間割をインポート';

  @override
  String get chooseImportMethod => 'インポート方法を選択してください。';

  @override
  String get importAsNewTimetable => '新しい時間割としてインポート';

  @override
  String get replaceCurrentTimetable => '現在の時間割を置き換え';

  @override
  String get importPeriodTimeSetDialogTitle => '時限時間セットをインポート';

  @override
  String get importPeriodTimeSetDialogBody =>
      'このファイルには同梱の時限時間セットが含まれています。インポートして関連付けますか？';

  @override
  String get importBundledPeriodTimeSets => 'インポートして関連付け';

  @override
  String get discardBundledPeriodTimeSets => '同梱セットを破棄';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      '既存の時限時間セットがないため、同梱の時限時間セットを破棄できません。';

  @override
  String savedToPath(Object path) {
    return '$path に保存しました';
  }

  @override
  String get saveCancelled => '保存をキャンセルしました';

  @override
  String get fileSaveRestrictedTitle => 'ファイル保存が制限されています';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'システムがファイルを保存できませんでした。再試行するか、代わりに共有を使用してください。';

  @override
  String get retrySave => 'もう一度保存';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'システム設定でファイルアクセスを有効にしてから戻り、再度エクスポートしてください。';

  @override
  String get openSettings => '設定を開く';

  @override
  String get browserDownloadRestrictedTitle => 'ブラウザでのダウンロードが制限されています';

  @override
  String get browserDownloadRestrictedMessage =>
      'このブラウザではローカルファイルへ直接保存できません。ブラウザのダウンロード権限を確認するか、代わりにファイル共有を使用してください。';

  @override
  String get switchToShare => '代わりに共有を使う';

  @override
  String get fileSaveFailedTitle => 'ファイルの保存に失敗しました';

  @override
  String get fileSaveFailedWindowsMessage =>
      '現在のパスに書き込めません。保存先フォルダーが保護されているか、ファイルが使用中か、パスに書き込み権限がない可能性があります。';

  @override
  String get fileSaveFailedGenericMessage =>
      'システムがファイルを保存できませんでした。再試行するか、システム設定を確認するか、代わりにファイル共有を使用してください。';

  @override
  String get retryLater => '後でもう一度試す';

  @override
  String get exportSwitchedToShare => 'エクスポートはファイル共有に切り替えられました';

  @override
  String get saveFailedRetry => '保存に失敗しました。後でもう一度お試しください。';

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
  String get appInstanceBlockedTitle => 'Sked はすでに開いています';

  @override
  String get appInstanceBlockedMessage =>
      '別の Sked ウィンドウまたはブラウザータブがローカルデータを使用しています。閉じてから、もう一度お試しください。';

  @override
  String get appInstanceLeaseFailedTitle => 'ローカルデータを利用できません';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked はローカルデータへの排他アクセスを確認できませんでした。データは開かれておらず、変更もされていません。ストレージへのアクセスを確認してから、もう一度お試しください。';

  @override
  String get savingChanges => '変更を保存しています…';

  @override
  String get showApiKey => 'API キーを表示';

  @override
  String get hideApiKey => 'API キーを非表示';

  @override
  String get importFailedCheckContent => 'インポートに失敗しました。ファイル内容を確認してください。';

  @override
  String get noImportableTimetables => 'インポートしたファイルに使用可能な時間割が見つかりませんでした。';

  @override
  String importedTimetablesCount(int count) {
    return '$count件の時間割をインポートしました';
  }

  @override
  String get periodTimesTitle => '時限時間';

  @override
  String get importExport => 'インポートとエクスポート';

  @override
  String get importPeriodTemplate => '時限テンプレートをインポート';

  @override
  String get importPeriodTemplateText => 'テキストから時限テンプレートをインポート';

  @override
  String get sharePeriodTemplate => '時限テンプレートを共有';

  @override
  String get saveTemplateToFile => 'テンプレートをファイルに保存';

  @override
  String get exportPeriodTemplateText => '時限テンプレートをテキストでエクスポート';

  @override
  String get deletePeriodTimeSet => '時限時間セットを削除';

  @override
  String get periodTimeSetName => '時限時間セット名';

  @override
  String get addOnePeriod => '時限を追加';

  @override
  String periodNumberLabel(int index) {
    return '第$index時限';
  }

  @override
  String get deleteThisPeriod => 'この時限を削除';

  @override
  String durationMinutes(int minutes) {
    return '長さ $minutes分';
  }

  @override
  String gapFromPrevious(int minutes) {
    return '前の時限からの間隔 $minutes分';
  }

  @override
  String get endTimeMustBeLater => '終了時刻は開始時刻より後である必要があります';

  @override
  String get periodOverlapPrevious => 'この時限は前の時限と重なっています';

  @override
  String get periodTimesSaved => '時限時間を保存しました';

  @override
  String get deletePeriodTimeSetTitle => '時限時間セットを削除';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return '\"$name\"を削除しますか？';
  }

  @override
  String get currentPeriodTimeSet => '現在の時限時間セット';

  @override
  String importedPeriodTimesCount(int count) {
    return '$count件の時限時間をインポートしました';
  }

  @override
  String get periodFilePermissionTitle => 'ファイル権限が必要です';

  @override
  String get androidFilePermissionMessage =>
      'Androidでのエクスポートにはファイルアクセス権限が必要です。保存を続けるには権限を許可してください。';

  @override
  String get reauthorize => '再許可';

  @override
  String get permissionPermanentlyDeniedTitle => '権限が恒久的に拒否されました';

  @override
  String get permissionSettingsExportMessage =>
      'システム設定でファイルアクセスを有効にしてから戻り、再度エクスポートしてください。';

  @override
  String get privacyPolicyTitle => 'プライバシーポリシー';

  @override
  String get privacyPolicyEntryDesc =>
      'アプリがローカル保存、学校サイト設定、ファイルのインポート/エクスポート、Webページ解析、外部リンクをどのように扱うかを確認できます。';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return '同意済みバージョン: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked はローカル優先の時間割ツールです。時間割、時限時間セット、学校サイト設定はお使いの端末またはブラウザ内にのみ保存され、自動的にアップロードされることはありません。アプリは、インポート、ウェブページ解析、共有、外部リンクの起動など、あなたが明示的に操作を行った場合にのみデータを処理します。完全なプライバシーポリシーはオンラインで確認できます。';

  @override
  String get privacyPolicyLocalStorageTitle => 'ローカル保存';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'インポートとエクスポート';

  @override
  String get privacyPolicyImportExportBody =>
      'アプリが時間割JSONファイル、学校サイトJSONファイル、時限テンプレートファイルを読み書きするのは、あなたが明示的にファイルを選択するか、エクスポート操作を開始した場合のみです。これらのファイルのインポートは、Webページ解析も選択しない限りローカル処理です。カスタムモデル一覧の取得も明示的なネットワーク操作であり、設定したカスタムエンドポイントのみに接続します。';

  @override
  String get privacyPolicySharingTitle => '共有';

  @override
  String get privacyPolicySharingBody =>
      '共有機能を明示的に使用した場合、アプリはエクスポートしたファイルをシステムの共有シート、またはあなたが選択した対象アプリへ渡します。その後のファイルの取り扱いは、選択した対象アプリまたはサービスに依存します。';

  @override
  String get privacyPolicyExternalLinksTitle => '外部リンク';

  @override
  String get privacyPolicyExternalLinksBody =>
      'GitHub リポジトリなどの外部リンクを開くと、アプリはその操作をブラウザまたは他の外部アプリに引き渡します。その後のデータの取り扱いは、開いた第三者によって決まります。';

  @override
  String get privacyPolicyNoCollectionTitle => 'アプリが収集しないもの';

  @override
  String get privacyPolicyNoCollectionBody =>
      'アプリは Sked アカウントを必要とせず、分析、広告識別子、クラウドバックアップも有効にしません。また、学校アカウントのパスワードを収集する専用入力欄も提供しません。アプリ内で学校サイトにログインする場合、その操作はあなたが開いた学校ページ上で行われます。';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Webページ解析';

  @override
  String get privacyPolicyFutureFeatureBody =>
      '学校のウェブページ取り込みを使用する場合、または貼り付けた時間割テキスト / HTML を解析する場合、アプリはまず内容をローカルで整形して不要な部分を取り除き、その後、送信された時間割テキスト、ページ本文または HTML 内容、任意のページタイトルと URL、現在のアプリ言語、解析用プロンプトの内容を、あなたが設定した OpenAI 互換エンドポイントへ送信します。モデル一覧の取得でも同じエンドポイントへリクエストします。Sked は組み込みの解析エンドポイントを提供せず、開発者が管理する時間割解析バックエンドへ解析リクエストを送信することもありません。カスタムエンドポイントおよびその上流サービスは、選択したサービス提供者の規則に従って、データを保存、転送、制限、削除、またはその他の方法で処理する場合があります。http:// Base URL を使用する場合は、内容や API キーが転送時暗号化で保護されない可能性があるため、信頼できる端末、ネットワーク、エンドポイントサービスでのみ使用してください。';

  @override
  String get privacyPolicyUpdatesTitle => 'ポリシーの更新';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return '現在のプライバシーポリシーのバージョンは $version です。今後のバージョンでデータの取り扱い方法が変わる場合、更新後のポリシーの再確認と再同意をお願いすることがあります。';
  }

  @override
  String get privacyGateTitle => 'アプリを使用する前にプライバシーポリシーへ同意してください';

  @override
  String get privacyGateSummaryStorage =>
      '時間割、時限時間セット、学校サイト設定はローカルにのみ保存され、開発者サーバーへ自動アップロードされません。';

  @override
  String get privacyGateSummaryImportExport =>
      'インポート、エクスポート、共有は、あなたが明示的に開始した場合にのみ行われます。Webページ解析では、送信した圧縮済み内容のみが設定した解析エンドポイントへ送られ、保存前に解析結果の時間割を確認できます。';

  @override
  String get privacyGateSummaryUpdates =>
      '今後のバージョンでデータの取り扱いが変わる場合、更新後のプライバシーポリシーの再確認をお願いすることがあります。';

  @override
  String get schoolWebImportEntry => '学校Webページからインポート';

  @override
  String get schoolWebImportEntryDesc => '学校サイト上の現在の時間割ページをインポートします。';

  @override
  String get schoolSitesManageEntry => '学校サイトを管理';

  @override
  String get schoolSitesManageEntryDesc =>
      '学校ログインURLの追加・編集・削除を行い、JSONのインポート/エクスポートにも対応します。';

  @override
  String get schoolSitesPageTitle => '学校サイト管理';

  @override
  String get schoolSitesImportJson => '学校JSONをインポート';

  @override
  String get schoolSitesShareJson => '学校JSONを共有';

  @override
  String get schoolSitesSaveJson => '学校JSONを保存';

  @override
  String get schoolSitesSaved => '学校サイトを保存しました';

  @override
  String get schoolSitesImported => '学校サイトをインポートしました';

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
  String get schoolSitesEmpty => '学校サイト設定はまだありません。';

  @override
  String get schoolSitesNameLabel => '学校名';

  @override
  String get schoolSitesLoginUrlLabel => 'ログインURL';

  @override
  String get schoolSitesAdd => '学校を追加';

  @override
  String get schoolSitesEdit => '学校を編集';

  @override
  String get schoolSitesDeleteTitle => '学校を削除';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return '\"$name\"を削除しますか？';
  }

  @override
  String get schoolSitesFormInvalid => '先に学校名とログインURLを入力してください。';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry => '時間割ページ内容を貼り付けてインポート';

  @override
  String get schoolHtmlImportEntryDesc =>
      '時間割情報を含むソースコードまたはページの生データを手動で貼り付けます。';

  @override
  String get schoolHtmlImportPageTitle => 'ページ内容から時間割を解析';

  @override
  String get schoolHtmlImportUrlLabel => '元のURL（任意）';

  @override
  String get schoolHtmlImportTitleLabel => 'ページタイトル（任意）';

  @override
  String get schoolHtmlImportHtmlLabel => 'ページ内容';

  @override
  String get schoolHtmlImportHtmlHint =>
      '時間割情報を含むソースコードまたはページの生データをここに貼り付けてください。';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'HTMLに限らず、時間割情報を含む内容であれば解析してインポートできます。';

  @override
  String get schoolHtmlImportCompress => '内容を整理';

  @override
  String get schoolHtmlImportCompressed => '内容を整理しました';

  @override
  String get schoolHtmlImportCompressFirst => '先に内容を整理してください。';

  @override
  String get schoolHtmlImportSubmit => '解析してインポート';

  @override
  String get schoolImportContentTruncated =>
      'このページは安全なインポート上限に達しました。取得できた部分だけが解析のために送信されます。';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      '解析には時間がかかる場合があります。しばらくお待ちください。';

  @override
  String get schoolHtmlImportEmpty => '先にページHTMLを貼り付けてください。';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Webページに戻る';

  @override
  String get schoolWebImportPageTitle => '学校Webページのインポート';

  @override
  String get schoolWebImportPreview => 'インポートプレビュー';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count件の授業';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count時限';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'ページタイトル';

  @override
  String get schoolWebImportParserUsed => 'パーサー';

  @override
  String get schoolWebImportWarnings => 'インポート時の注意';

  @override
  String get schoolWebImportParserDetails => '解析の詳細';

  @override
  String get schoolWebImportExpandParserDetails => '解析の詳細を展開';

  @override
  String get schoolWebImportCollapseParserDetails => '解析の詳細を折りたたむ';

  @override
  String get schoolWebImportOpenPageHint =>
      'アプリ内で学校サイトにログインし、その後手動で時間割ページへ移動してください。';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'このプラットフォームでは、埋め込みWebログインはまだサポートされていません。WebView対応のプラットフォームを使用してください。';

  @override
  String get schoolWebImportSelectSchool => '学校を選択';

  @override
  String get schoolWebImportNoSchools =>
      '学校設定がありません。まず school_sites.json を確認してください。';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      '学校設定の読み込みに失敗しました。JSONファイル形式を確認してください。';

  @override
  String get schoolWebImportImportCurrentPage => '現在のページをインポート';

  @override
  String get schoolWebImportLoadingPage => 'ページを読み込み中…';

  @override
  String get schoolWebImportParsing => '現在のページを解析中…';

  @override
  String get schoolWebImportLoadFailed =>
      'ページの読み込みに失敗しました。更新するか、しばらくしてからもう一度お試しください。';

  @override
  String get schoolWebImportUnknownOrigin => '不明なサイト';

  @override
  String get schoolWebImportExitTitle => 'ブラウザーを終了しますか？';

  @override
  String get schoolWebImportExitMessage => 'ページが閉じます。まだインポートしていない内容は失われます。';

  @override
  String get schoolWebImportExitConfirm => '終了';

  @override
  String get schoolWebImportEmptyPage => '現在のページ内容が空のため、まだインポートできません。';

  @override
  String get schoolWebImportSuccess => 'Web時間割をインポートしました';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'パーサーの提供元';

  @override
  String get schoolImportParserSourceCustomOpenAi => 'カスタム OpenAI 互換';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi => 'カスタム OpenAI 互換パーサー';

  @override
  String get schoolImportParserCustomPromptTitle => 'カスタムプロンプト';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'ここで組み込みパーサープロンプトを編集できます。変更はカスタム OpenAI 互換パーサーにのみ適用されます。';

  @override
  String get schoolImportParserCustomPromptHint =>
      'ここには既定で組み込みプロンプトが読み込まれます。空にすると組み込み版に戻ります。';

  @override
  String get schoolImportParserResetDefaultPrompt => '既定のプロンプトに戻す';

  @override
  String get schoolImportParserBaseUrl => 'Base URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL はホストを含む HTTP または HTTPS の URL にしてください。';

  @override
  String get schoolImportParserApiKey => 'API key';

  @override
  String get schoolImportParserModel => 'モデル';

  @override
  String get schoolImportParserFetchModels => 'モデル一覧を取得';

  @override
  String get schoolImportParserFetchingModels => 'モデルを取得中...';

  @override
  String get schoolImportParserNoModelsFound => 'エンドポイントからモデルが返されませんでした。';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'モデルを取得できませんでした。エンドポイントを確認して、もう一度お試しください。';

  @override
  String schoolImportParserModelsFetched(int count) {
    return '$count件のモデルを取得しました';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      '暗号化されていない HTTP エンドポイントを使用しますか？';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'API キーと時間割の内容は、通信中に読み取られたり改ざんされたりする可能性があります。このデバイス、ネットワーク、エンドポイントを信頼できる場合のみ続行してください。この許可は Sked を閉じるまで有効です。';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'カスタムパーサー設定が未完了です。先に Base URL、API key、モデルを入力してください。';

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
    return 'パーサー: カスタム ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'プライバシーポリシー全文を見る';

  @override
  String get privacyAgreeAndContinue => '同意して続行';

  @override
  String get privacyDecline => '同意しない';

  @override
  String get privacyDeclineWebHint =>
      'このブラウザ環境では、アプリがページを自動で閉じることはできません。同意しない場合は、このタブまたはウィンドウを自分で閉じてください。';

  @override
  String get defaultPeriodTimeSetName => 'デフォルト時限';

  @override
  String get periodTimeSetFallbackName => '時限時間';

  @override
  String get untitledTimetableName => '無題の時間割';

  @override
  String get newTimetableName => '新しい時間割';

  @override
  String get newPeriodTimeSetName => '新しい時限時間セット';

  @override
  String get emptyTimetableName => '空の時間割';

  @override
  String importedPeriodTimeSetName(Object name) {
    return '$name の時限';
  }

  @override
  String get importFileTypeMismatchMessage => 'インポートするファイルの種類が一致しません。';

  @override
  String get importFileVersionUnsupportedMessage =>
      'このインポートファイルのバージョンにはまだ対応していません。';

  @override
  String get noPeriodTimesInImportMessage => 'インポートファイルに時限時間が見つかりませんでした。';

  @override
  String get selectAtLeastOneTimetableMessage => '少なくとも1つの時間割を選択してください。';

  @override
  String get noExportableTimetableMessage => 'エクスポートできる時間割がありません。';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      '現在の時間割の置き換えでは、1つの時間割のみ選択できます。';

  @override
  String get noActiveTimetableToReplaceMessage => '置き換える現在の時間割がありません。';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'この時限時間セットはまだ $count 件の時間割で使用されています。削除する前に別のセットへ割り当て直してください。';
  }

  @override
  String get weekdayMonday => '月曜日';

  @override
  String get weekdayTuesday => '火曜日';

  @override
  String get weekdayWednesday => '水曜日';

  @override
  String get weekdayThursday => '木曜日';

  @override
  String get weekdayFriday => '金曜日';

  @override
  String get weekdaySaturday => '土曜日';

  @override
  String get weekdaySunday => '日曜日';

  @override
  String get weekdayShortMonday => '月';

  @override
  String get weekdayShortTuesday => '火';

  @override
  String get weekdayShortWednesday => '水';

  @override
  String get weekdayShortThursday => '木';

  @override
  String get weekdayShortFriday => '金';

  @override
  String get weekdayShortSaturday => '土';

  @override
  String get weekdayShortSunday => '日';

  @override
  String get monthJanuary => '1月';

  @override
  String get monthFebruary => '2月';

  @override
  String get monthMarch => '3月';

  @override
  String get monthApril => '4月';

  @override
  String get monthMay => '5月';

  @override
  String get monthJune => '6月';

  @override
  String get monthJuly => '7月';

  @override
  String get monthAugust => '8月';

  @override
  String get monthSeptember => '9月';

  @override
  String get monthOctober => '10月';

  @override
  String get monthNovember => '11月';

  @override
  String get monthDecember => '12月';

  @override
  String get semesterWeeksWholeTerm => '学期全体';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return '第$start〜$end週';
  }

  @override
  String semesterWeeksList(Object value) {
    return '第$value週';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => '開始モードを選択';

  @override
  String get firstLaunchSubtitle => 'よく使うワークスペースを選択してください。モードは後から切り替えられます。';

  @override
  String get firstLaunchStudentDesc => '時間割、科目、週、時限、インポートを管理します。';

  @override
  String get firstLaunchGeneralDesc => 'カテゴリ、イベント、リマインダー、JSON / ICS データを管理します。';

  @override
  String get firstLaunchStartStudent => '時間割で開始';

  @override
  String get firstLaunchStartGeneral => '予定で開始';

  @override
  String get firstLaunchPrivacyConsentBefore => '開始ワークスペースを選択すると、';

  @override
  String get firstLaunchPrivacyConsentLink => 'プライバシーポリシー';

  @override
  String get firstLaunchPrivacyConsentAfter => 'を読み、同意したものとみなされます。';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => '今日';

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
  String get generalDisplaySettingsDesc => '表示形式、ツールバー、日付形式、クイック追加';

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
  String get viewWeek => '週';

  @override
  String get viewDay => '日';

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
  String get developerModeTitle => '開発者モード';

  @override
  String get developerModeDescription => '表示と操作の確認に使う一式のサンプルデータを追加できます。';

  @override
  String get developerSampleLanguage => 'サンプルデータの言語';

  @override
  String get developerSampleChinese => '中国語';

  @override
  String get developerSampleEnglish => '英語';

  @override
  String get developerSampleDataDescription =>
      '既存のデータを置き換えずに、時間割 1 件とカテゴリ・予定一式を追加します。';

  @override
  String get developerAddSampleData => 'サンプルデータを追加';

  @override
  String get developerSampleDataAdded => 'サンプルの時間割と予定を追加しました。';

  @override
  String get developerModeLongPressHint => '3 秒間長押しすると開発者モードが開きます';

  @override
  String get developerNotificationDiagnostics => 'Notification diagnostics';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Inspect Android delivery state, rebuild the existing reminder plan, and send safe test notifications through Sked\'s normal notification service.';

  @override
  String get developerNotificationUnsupported =>
      'Notification diagnostics are available on Android only.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Notification diagnostics are unavailable until the agenda coordinator starts.';

  @override
  String get developerNotificationRefresh => 'Refresh diagnostics';

  @override
  String get developerNotificationSystemStatus =>
      'System notification permission';

  @override
  String get developerNotificationPermissionAllowed => 'Allowed';

  @override
  String get developerNotificationPermissionBlocked => 'Blocked';

  @override
  String get developerNotificationExactAlarm => 'Exact alarms';

  @override
  String get developerNotificationExactAlarmAllowed => 'Allowed';

  @override
  String get developerNotificationExactAlarmInexact => 'Inexact fallback';

  @override
  String get developerNotificationPlan => 'Agenda notification plan';

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled scheduled, $planned planned';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Last error: $message';
  }

  @override
  String get developerNotificationRunMaintenance => 'Rebuild notification plan';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Notification plan rebuilt.';

  @override
  String get developerNotificationTestChannel => 'Test channel';

  @override
  String get developerNotificationTestCourse => 'Course reminders';

  @override
  String get developerNotificationTestSchedule => 'Schedule reminders';

  @override
  String get developerNotificationImmediateTest => 'Send immediate test';

  @override
  String get developerNotificationThirtySecondTest =>
      'Schedule 30-second background test';

  @override
  String get developerNotificationImmediateQueued =>
      'Immediate test notification sent.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Background test scheduled for 30 seconds.';

  @override
  String get developerNotificationAppSwitch => 'App reminder switch';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Enabled for normal reminders';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Disabled for normal reminders; developer tests can still run';

  @override
  String get developerNotificationTimeZone => 'Local time zone';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Not created yet. A developer test will create it.';

  @override
  String get developerNotificationChannelEnabledState => 'Enabled';

  @override
  String get developerNotificationChannelBlockedState => 'Blocked';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Importance: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Importance unavailable';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'No reconciliation recorded yet.';

  @override
  String get developerNotificationNextReminder => 'Next real reminder';

  @override
  String get developerNotificationNoPendingReminder =>
      'No future reminder in the current plan';

  @override
  String get developerNotificationNextMaintenance => 'Next maintenance';

  @override
  String get developerNotificationNoMaintenance => 'Not scheduled';

  @override
  String get developerNotificationTruncation => 'Plan truncation';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count omitted by the plan limit';
  }

  @override
  String get developerNotificationLastReconciliation => 'Latest reconciliation';

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
  String get developerNotificationReconcileOriginForeground => 'Foreground';

  @override
  String get developerNotificationReconcileOriginBackground => 'Background';

  @override
  String get developerNotificationReconcileModeAuthoritative => 'Authoritative';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Maintenance';

  @override
  String get developerNotificationReconcileResultSuccess => 'Succeeded';

  @override
  String get developerNotificationReconcileResultSkipped => 'Skipped';

  @override
  String get developerNotificationReconcileResultFailed => 'Failed';

  @override
  String get developerNotificationTestChecking =>
      'Tests are unavailable while notification status is being checked.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Tests are unavailable because system notifications are blocked.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Tests are unavailable because the selected notification channel is blocked.';

  @override
  String get collapseWorkspaceNavigation => 'ワークスペースナビゲーションを折りたたむ';

  @override
  String get expandWorkspaceNavigation => 'ワークスペースナビゲーションを展開する';

  @override
  String get schoolWebImportExitBrowser => 'アプリ内ブラウザを終了';

  @override
  String get schoolWebImportEditAddress => 'アドレスを編集';

  @override
  String get schoolWebImportAddressLabel => 'ウェブアドレス';

  @override
  String get schoolWebImportOpenAddress => '開く';

  @override
  String get schoolWebImportAddressInvalid =>
      'ホストを含む HTTP または HTTPS アドレスを入力してください。';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'このウェブページは、このデバイスで開けない新しいウィンドウを要求しました。';

  @override
  String get schoolWebImportSecureConnection => '安全な接続';

  @override
  String get schoolWebImportInsecureConnection => '安全でない接続';

  @override
  String get schoolWebImportSignInConsentTitle => '学校のログインページを開きますか？';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return '学校へのログインでは、フォームやサーバーのリダイレクトを通じて、学校やログインサービス提供元に認証情報が送信される場合があります。Android では、このような送信を毎回停止して移動先を個別に確認することはできません。今回のインポートセッションでこれらを信頼できる場合のみ続行してください：\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle => '安全でない学校ログインを開きますか？';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'この学校ログインは HTTP を使用しています。この接続を監視または改ざんできる第三者に、認証情報やページ内容を読み取られたり変更されたりする可能性があります。次のサイトについてこのリスクを受け入れる場合のみ続行してください：\n\n$origin';
  }

  @override
  String get notificationSettingsSection => 'Reminders & notifications';

  @override
  String get notificationSettingsEnabled =>
      'Enable reminders and notifications';

  @override
  String get notificationSettingsEnabledHint =>
      'Schedules only items with a reminder. Set a course default below for courses that inherit it.';

  @override
  String get notificationSettingsEnabledSummary => 'Enabled';

  @override
  String get notificationSettingsDisabledSummary => 'Disabled';

  @override
  String get notificationDefaultsSection => 'Default reminders';

  @override
  String get notificationCourseDefaultReminder => 'Course default reminder';

  @override
  String get notificationGeneralDefaultReminder => 'Schedule default reminder';

  @override
  String get notificationReminderOff => 'No reminder';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String get notificationPermission => 'Notification permission';

  @override
  String get notificationPermissionGranted => 'Allowed by the system';

  @override
  String get notificationPermissionDenied => 'Blocked by the system';

  @override
  String get notificationPermissionChecking => 'Checking permission…';

  @override
  String get notificationPermissionRequest => 'Request permission';

  @override
  String get notificationPermissionOpenSettings => 'Open system settings';

  @override
  String get notificationPermissionRequestFailed =>
      'Could not read notification permission. Try again.';

  @override
  String get notificationExactAlarm => 'Exact alarm permission';

  @override
  String get notificationExactAlarmAllowed => 'Allowed by the system';

  @override
  String get notificationExactAlarmRequired =>
      'Required for precise reminder times';

  @override
  String get notificationExactAlarmRequest => 'Allow exact alarms';

  @override
  String get notificationLockScreenTitles => 'Show titles on the lock screen';

  @override
  String get notificationLockScreenTitlesHint =>
      'When off, notification details stay private on the lock screen.';

  @override
  String get notificationWidgets => 'Home screen widgets';

  @override
  String get notificationWidgetsDesc =>
      'Refresh Sked widgets and learn how to add one from the launcher.';

  @override
  String get notificationWidgetsDialogTitle => 'Add a Sked widget';

  @override
  String get notificationWidgetsDialogMessage =>
      'From your device launcher, touch and hold an empty area, choose Widgets, and add a Sked widget. The widget shows your next courses or events.';

  @override
  String get notificationWidgetsRefresh => 'Refresh widgets';

  @override
  String get notificationWidgetsRefreshed => 'Widgets refreshed';

  @override
  String get notificationPlatformUnsupported =>
      'This platform does not provide native notifications.';
}
