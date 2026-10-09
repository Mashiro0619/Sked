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
  String get schoolImportExpandWarnings => 'インポートの警告を展開';

  @override
  String get schoolImportCollapseWarnings => 'インポートの警告を折りたたむ';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return '第$week週まで続く授業があります。';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle => '現在の時間割を置き換えますか？';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'インポートした時間割で現在の時間割を置き換えます。';

  @override
  String get createTimetable => '新しい時間割';

  @override
  String get jumpToWeek => '週へ移動';

  @override
  String get timetable => '時間割';

  @override
  String get themeWorkspaceSchedule => 'スケジュール';

  @override
  String get timetableName => '時間割名';

  @override
  String get timetableNameRequired => '時間割名を入力してください';

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
  String get customFieldsInvalidJson => '有効な JSON オブジェクトを入力するか、フィールドを空にしてください。';

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
  String get settingsSectionTimetable => '時間割';

  @override
  String get settingsSectionGeneralSchedule => 'スケジュール';

  @override
  String get settingsSectionAppearance => '外観';

  @override
  String get settingsSectionApp => 'アプリ';

  @override
  String get settingsSectionWorkspace => 'ワークスペース';

  @override
  String get settingsSectionAppearanceLanguage => '外観と言語';

  @override
  String get settingsSectionDataSecurity => 'データとセキュリティ';

  @override
  String get settingsSectionAbout => 'Sked について';

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
  String get timetableHorizontalLayoutSection => '横方向の表示とジェスチャー';

  @override
  String get fitDaySelectorToWidth => '曜日選択を画面幅に合わせる';

  @override
  String get fitDaySelectorToWidthHint =>
      '可能な限り7日分を画面内に表示します。オフにすると固定幅になり、スクロールで移動できます。';

  @override
  String get fitWeekColumnsToWidth => '時間割の列を画面幅に合わせる';

  @override
  String get fitWeekColumnsToWidthHint =>
      '可能な限り7日分の列を画面内に表示します。オフにすると固定幅になり、スクロールで移動できます。';

  @override
  String get enableWeekSwipeNavigation => 'スワイプで週を切り替える';

  @override
  String get enableWeekSwipeNavigationHint =>
      '左右にスワイプすると前後の週に移動します。固定幅の場合は、まず端までスクロールしてください。';

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
  String get microsoftStoreUpdates => '更新は Microsoft Store で管理されます';

  @override
  String get includePrereleaseUpdates => 'プレリリース版の更新を受け取る';

  @override
  String get includePrereleaseUpdatesDesc =>
      '不安定な可能性がある Alpha、Beta、RC 版も確認します。オフの場合は安定版のみが対象です。';

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
      'GitHub から最新バージョンを取得できませんでした。下のボタンから GitHub Releases を開くことはできます。';

  @override
  String get githubRepository => 'GitHubリポジトリ';

  @override
  String get googlePlayStoreDesc => 'Google Play で Sked を表示';

  @override
  String get openGooglePlayFailed => 'Google Play を開けませんでした';

  @override
  String get starSkedOnGithub => 'GitHub で Sked にスターを！';

  @override
  String get starSkedOnGithubDesc => 'リポジトリを開いて Sked にスターを付ける';

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
  String get periodTimesUnsavedExitTitle => '変更は保存されていません';

  @override
  String get periodTimesSaveFailureExitMessage =>
      '時限の時刻の変更を保存できませんでした。再試行、編集の続行、または変更の破棄を選べます。';

  @override
  String get periodTimesInvalidExitMessage =>
      '無効な時限の時刻があります。修正して保存するか、変更を破棄して終了してください。';

  @override
  String get discardChangesAndExit => '変更を破棄して終了';

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
      'ネイティブ版の Sked は、時間割、スケジュール、関連設定、編集可能な学校サイト設定を OS のアプリ用サポートディレクトリに保存します。ブラウザー版はブラウザーのストレージを使用します。旧バージョンがユーザーのドキュメントフォルダーに保存したファイルは残りますが、自動で読み込んだり移行したりはしません。そのデータを引き継ぐには、更新前に旧バージョンからアプリ全体のバックアップをエクスポートし、更新後に復元してください。AI API 設定は端末内に保存され、カスタム API キーは利用可能な場合、プラットフォームの安全なストレージに保存されます。アプリ全体のバックアップにカスタム API キーは含まれません。これらのローカルデータが開発者の管理するサーバーへ自動的に送信されることはありません。';

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
  String get schoolSitesImportPreviewTitle => '学校サイトのインポートを確認';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '有効なサイト $validCount 件、無効な項目 $invalidCount 件。';
  }

  @override
  String get schoolSitesImportEmptyPreview => 'ファイル内の学校サイト一覧は空です。';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return '項目 $position は無効なためスキップします。';
  }

  @override
  String get schoolSitesImportMerge => '統合';

  @override
  String get schoolSitesImportReplace => '置き換え';

  @override
  String get schoolSitesImportReplaceConfirmTitle => '現在の学校サイトを置き換えますか？';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return '現在の $currentCount 件のサイトを削除し、インポートした $importedCount 件を保存します。この操作は取り消せません。';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle => '学校サイトのデータの復旧が必要です';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      '学校サイトのファイルとバックアップを読み込めませんでした。書き込みを停止する前に保護用コピーを作成しました。';

  @override
  String get schoolSitesRecoveryIoFailureTitle => '学校サイトのストレージを利用できません';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      '現在、学校サイトのストレージにアクセスできません。ストレージへのアクセス権や端末の状態を確認してから再試行してください。現在のサイトデータは上書きしません。';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      '復旧用ファイルや影響を受けた保存場所を以下に表示します。サイト一覧が復旧するまで、これらのファイルを変更しないでください。';

  @override
  String get schoolSitesRecoveryStartFreshAction => '学校サイトを空にして開始';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle => '学校サイト一覧を空にして開始しますか？';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      '保護用コピーを残したまま、新しい空の学校サイトファイルを作成します。先に復旧を再試行する必要がない場合のみ続行してください。';

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
      'カスタム解析サービスの設定が不完全です。まずベース URL、API キー、モデルを入力してください。';

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
  String get schoolImportParserSettingsTitle => '時間割解析 API';

  @override
  String get schoolImportParserSettingsDesc =>
      '時間割のインポート用に OpenAI 互換 API を設定します。チャットアシスタントの設定ではありません。';

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
  String get schoolImportParserBaseUrl => 'ベース URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL はホストを含む HTTP または HTTPS の URL にしてください。';

  @override
  String get schoolImportParserApiKey => 'API キー';

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
      'カスタム API キーは、利用可能な場合、プラットフォームの安全なストレージに保存されます。カスタム解析サービスの認証情報や HTTP 接続先は、信頼できる端末、ブラウザー、ネットワークでのみ使用してください。';

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
  String get clearAppData => 'データを消去';

  @override
  String get clearAppDataDesc => '端末内の Sked データをすべて完全に削除してアプリを終了';

  @override
  String get clearAppDataConfirmTitle => 'Sked のデータをすべて消去しますか？';

  @override
  String get clearAppDataConfirmMessage =>
      '時間割、スケジュール、設定、学校サイト、ローカルバックアップ、復旧用コピー、AI API キーを完全に削除し、Sked を終了します。別の場所にエクスポートしたファイルは削除しません。この操作は取り消せません。';

  @override
  String get clearAppDataAction => 'データを消去して終了';

  @override
  String get clearAppDataFailed =>
      'ローカルデータをすべて消去できませんでした。再試行できるように Sked は開いたままになります。';

  @override
  String get clearAppDataExitFailed =>
      'ローカルデータは消去しましたが、Sked を終了できませんでした。再び使用する前にアプリを手動で終了してください。';

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
  String get generalSchedule => 'スケジュール';

  @override
  String get studentTimetable => '授業時間割';

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
  String get switchMode => 'モードを切り替え';

  @override
  String get generalScheduleComingSoon => 'スケジュール機能は近日公開です';

  @override
  String get switchToStudentTimetable => '授業時間割に切り替え';

  @override
  String get mySchedule => '自分のスケジュール';

  @override
  String get today => '今日';

  @override
  String get addEvent => '予定を追加';

  @override
  String get editEvent => '予定を編集';

  @override
  String get eventTitle => 'タイトル';

  @override
  String get eventTitleRequired => 'タイトルを入力してください';

  @override
  String get eventStartTime => '開始時刻';

  @override
  String get eventEndTime => '終了時刻';

  @override
  String get eventDate => '日付';

  @override
  String get eventTime => '時刻';

  @override
  String get eventNotes => 'メモ';

  @override
  String get eventColor => '色';

  @override
  String get eventRecurrence => '繰り返し';

  @override
  String get recurrenceNone => '繰り返さない';

  @override
  String get recurrenceWeekly => '毎週';

  @override
  String get recurrenceEndDate => '終了日';

  @override
  String get recurrenceNoEndDate => '終了日なし';

  @override
  String get recurrenceSetEndDate => '設定';

  @override
  String get recurrenceChangeEndDate => '変更';

  @override
  String get repeatsWeekly => '毎週繰り返す';

  @override
  String recurrenceUntil(Object date) {
    return '$date まで';
  }

  @override
  String get switchToGeneralSchedule => 'スケジュールに切り替え';

  @override
  String get generalDisplaySettings => 'スケジュールの表示設定';

  @override
  String get generalDisplaySettingsDesc => '表示形式、ツールバー、日付形式、クイック追加';

  @override
  String get closePopupOnOutsideTap => '外側をタップしてポップアップを閉じる';

  @override
  String get showGridLines => 'グリッド線を表示';

  @override
  String get generalScheduleImportExport => 'カテゴリのインポートとエクスポート';

  @override
  String get generalScheduleImportExportDesc => 'スケジュールのカテゴリをインポートまたは共有';

  @override
  String get importGeneralSchedules => 'カテゴリをインポート';

  @override
  String get importGeneralSchedulesDesc => 'JSON ファイルからカテゴリを読み込む';

  @override
  String get shareGeneralSchedules => 'カテゴリを共有';

  @override
  String get shareGeneralSchedulesDesc => 'カテゴリを JSON ファイルとして共有';

  @override
  String get saveGeneralSchedules => 'カテゴリを保存';

  @override
  String get saveGeneralSchedulesDesc => 'カテゴリを JSON ファイルとして保存';

  @override
  String get selectSchedulesToExport => 'エクスポートするカテゴリを選択';

  @override
  String get selectSchedulesToImport => 'インポートするカテゴリを選択';

  @override
  String generalScheduleEventCount(int count) {
    return '予定：$count 件';
  }

  @override
  String importedSchedulesCount(int count) {
    return '$count 件のカテゴリをインポートしました';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      '新しいカテゴリとして追加しますか？それとも既存のカテゴリを置き換えますか？';

  @override
  String get addAsNewSchedule => '新しいカテゴリとして追加';

  @override
  String get selectAtLeastOneScheduleMessage => 'カテゴリを1つ以上選択してください。';

  @override
  String get noExportableScheduleMessage => 'エクスポートできるカテゴリがありません。';

  @override
  String get noSchedulesInImportMessage => 'インポートファイルにカテゴリがありません。';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      '置き換えに使用するカテゴリをインポート内容から1つだけ選択してください。';

  @override
  String get noActiveScheduleToReplaceMessage => '置き換え先のカテゴリを利用できません。';

  @override
  String get calendars => 'カテゴリ';

  @override
  String get calendar => 'カテゴリ';

  @override
  String get viewWeek => '週';

  @override
  String get viewDay => '日';

  @override
  String get viewList => 'リスト';

  @override
  String get viewMonth => '月';

  @override
  String visibleCategoryCount(int count) {
    return '$count 件のカテゴリ';
  }

  @override
  String get noVisibleCategories => '表示中のカテゴリはありません';

  @override
  String get selectCategoryToReplace => '置き換えるカテゴリを選択';

  @override
  String get replaceCategory => 'カテゴリを置き換え';

  @override
  String get deleteEventTitle => '予定を削除';

  @override
  String get deleteEventConfirmation => 'この予定は完全に削除されます。';

  @override
  String get deleteRecurringEventTitle => '繰り返し予定を削除';

  @override
  String get eventDuplicated => '予定を複製しました';

  @override
  String get searchEvents => '予定を検索';

  @override
  String get clearSearch => '検索をクリア';

  @override
  String get filterByColor => '色で絞り込む';

  @override
  String get allColors => 'すべての色';

  @override
  String upcomingEventsCount(int count) {
    return '今後の予定 $count 件';
  }

  @override
  String overdueEventsCount(int count) {
    return '終了時刻を過ぎた予定 $count 件';
  }

  @override
  String get allDay => '終日';

  @override
  String get collapseAllDayTimeline => '終日予定を折りたたむ';

  @override
  String get expandAllDayTimeline => '終日予定を展開';

  @override
  String allDayEventsCount(int count) {
    return '終日予定 $count 件';
  }

  @override
  String moreEvents(int count) {
    return 'ほか $count 件';
  }

  @override
  String get noMatchingEvents => '一致する予定はありません';

  @override
  String get noUpcomingEvents => '今後の予定はありません';

  @override
  String get addCalendar => 'カテゴリを追加';

  @override
  String get newCalendar => '新しいカテゴリ';

  @override
  String get hideCalendar => 'カテゴリを非表示';

  @override
  String get showCalendar => 'カテゴリを表示';

  @override
  String get rename => '名前を変更';

  @override
  String get renameCalendar => 'カテゴリ名を変更';

  @override
  String get name => '名前';

  @override
  String get deleteCalendar => 'カテゴリを削除';

  @override
  String deleteCalendarMessage(Object name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get deleteThisOccurrence => '今回のみ削除';

  @override
  String get deleteFutureOccurrences => '今回以降を削除';

  @override
  String get deleteAllOccurrences => '繰り返し全体を削除';

  @override
  String get duplicateEvent => '複製';

  @override
  String get repeatsDaily => '毎日繰り返す';

  @override
  String get repeatsMonthly => '毎月繰り返す';

  @override
  String repeatsEvery(int interval, Object unit) {
    return '$interval $unitごとに繰り返す';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count 回';
  }

  @override
  String get recurrenceDaily => '毎日';

  @override
  String get recurrenceMonthly => '毎月';

  @override
  String get recurrenceCustom => 'カスタム';

  @override
  String get recurrenceEvery => '間隔';

  @override
  String get recurrenceUnit => '単位';

  @override
  String get recurrenceDays => '日';

  @override
  String get recurrenceWeeks => '週';

  @override
  String get recurrenceMonths => 'か月';

  @override
  String get recurrenceRepeatCount => '繰り返し回数';

  @override
  String get recurrenceNoLimit => '無制限';

  @override
  String get recurrencePositiveNumber => '正の数を入力してください';

  @override
  String get clearEndDate => '終了日をクリア';

  @override
  String get pickDate => '日付を選択';

  @override
  String get pickTime => '時刻を選択';

  @override
  String get reminder => 'アプリ内リマインダー';

  @override
  String get reminderAtStart => '開始時';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes 分前';
  }

  @override
  String get reminderHourBefore => '1時間前';

  @override
  String get reminderDayBefore => '1日前';

  @override
  String get markReminderHandled => '確認済みにする';

  @override
  String get restoreReminder => 'アプリ内リマインダーを戻す';

  @override
  String get reminderHandled => 'アプリ内リマインダーを確認済みにしました';

  @override
  String get reminderRestored => 'アプリ内リマインダーを戻しました';

  @override
  String get reminderUpcoming => '開始前';

  @override
  String get reminderOverdue => '終了時刻経過';

  @override
  String get generalFitWeekColumnsToWidth => '週表示を画面に合わせる';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'コンパクトなレイアウトで週全体を表示します。オフにすると横スクロールになります。7日を超えるカスタム範囲は引き続き横スクロールできます。';

  @override
  String get showWeekends => '週末を表示';

  @override
  String get startHour => '表示開始時刻';

  @override
  String get endHour => '表示終了時刻';

  @override
  String get timeGridDensity => '時間グリッドの間隔';

  @override
  String get timeGridHourHeight => '1時間の行の高さ';

  @override
  String get timeGridHourHeightHint =>
      '15分・30分・60分のグリッド間隔を変えずに、日表示と週表示の縦方向の倍率を調整します。';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'JSON ファイルをインポート';

  @override
  String get pasteJson => 'JSON を貼り付け';

  @override
  String get importGeneralSchedulesJsonTextDesc => 'コピーした JSON からカテゴリをインポート';

  @override
  String get importIcsFile => 'ICS ファイルをインポート';

  @override
  String get importIcsFileDesc => '.ics カレンダーファイルから予定を読み込む';

  @override
  String get pasteIcs => 'ICS を貼り付け';

  @override
  String get pasteIcsDesc => 'コピーしたカレンダーテキストから予定をインポート';

  @override
  String get copyJson => 'JSON をコピー';

  @override
  String get copyJsonDesc => '選択したカテゴリを JSON テキストとしてコピー';

  @override
  String get shareIcs => 'ICS を共有';

  @override
  String get shareIcsDesc => '選択したカレンダーを .ics として共有';

  @override
  String get saveIcs => 'ICS を保存';

  @override
  String get saveIcsDesc => '選択したカレンダーを .ics として保存';

  @override
  String get copyIcs => 'ICS をコピー';

  @override
  String get copyIcsDesc => '選択したカレンダーを ICS テキストとしてコピー';

  @override
  String get importIcs => 'ICS をインポート';

  @override
  String get icsContent => 'ICS の内容';

  @override
  String get pasteIcsContentHint => 'BEGIN:VCALENDAR から始まる内容を貼り付けてください';

  @override
  String importIcsPreviewPrompt(int count) {
    return '$count 件の予定が見つかりました。新しいカテゴリとして追加しますか？それとも既存のカテゴリを置き換えますか？';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return '$count 件のカテゴリをインポートしました。警告：$warningCount 件';
  }

  @override
  String get importWarningSkippedMissingStart => '開始時刻のない予定をスキップしました。';

  @override
  String get importWarningSkippedUnsupportedStart => '未対応の開始時刻を含む予定をスキップしました。';

  @override
  String get importWarningAdjustedEnd => '開始時刻より後になっていない終了時刻を調整しました。';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return '未対応の ICS フィールドをメモに追加しました：$fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return '未対応の繰り返し頻度を無視しました：$frequency';
  }

  @override
  String get selectCalendarsToCopyIcs => 'ICS としてコピーするカレンダーを選択';

  @override
  String get selectCalendarsToExportIcs => 'ICS としてエクスポートするカレンダーを選択';

  @override
  String get exportIcsText => 'ICS テキストをエクスポート';

  @override
  String get exportJsonText => 'JSON テキストをエクスポート';

  @override
  String get dataRestoredFromBackupNotice =>
      'メインファイルを読み込めなかったため、前回のバックアップからアプリのデータを復元しました。';

  @override
  String get dataBackupRestoreFailedNotice =>
      'メインデータファイルとバックアップの両方が破損しています。現在、アプリは初期状態で動作しています。';

  @override
  String get dataRecoveryCorruptTitle => 'データの復旧が必要です';

  @override
  String get dataRecoveryCorruptMessage =>
      'メインデータファイルとバックアップを読み込めませんでした。書き込みを停止する前に保護用コピーを作成しました。';

  @override
  String get dataRecoveryIoFailureTitle => 'ストレージを利用できません';

  @override
  String get dataRecoveryIoFailureMessage =>
      '現在、ローカルストレージにアクセスできません。ストレージへのアクセス権や端末の状態を確認してから再試行してください。既存のデータは上書きしません。';

  @override
  String get dataRecoveryUnsupportedVersionTitle => 'このデータを開くには Sked を更新してください';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'このデータは新しいバージョンの Sked で作成されました。アプリを更新してから再試行してください。データを保護するため、新規データでの開始は無効になっています。';

  @override
  String get dataRecoveryRetryAction => '再試行';

  @override
  String get dataRecoveryArtifactsHint =>
      '復旧用ファイルや影響を受けた保存場所を以下に表示します。データが復旧するまで、これらのファイルを変更しないでください。';

  @override
  String get dataRecoveryArtifactsAction => '復旧用ファイルと保存場所を表示';

  @override
  String get dataRecoveryStartFreshAction => '新しいデータで開始';

  @override
  String get dataRecoveryStartFreshConfirmTitle => '新しいデータで開始しますか？';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      '保護用コピーを残したまま、新しいローカルデータファイルを作成します。先に復旧を再試行する必要がない場合のみ続行してください。';

  @override
  String get previousMonth => '前の月';

  @override
  String get nextMonth => '次の月';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes 分';
  }

  @override
  String get reminderInProgress => '進行中';

  @override
  String get deleteCourseTitle => '授業を削除';

  @override
  String get deleteCourseMessage => 'この授業を削除しますか？';

  @override
  String get showLunarCalendar => '旧暦を表示';

  @override
  String monthDayEvents(int day, int count) {
    return '$day日、予定 $count 件';
  }

  @override
  String get defaultView => '既定の表示';

  @override
  String get generalDefaultViewSection => '起動時';

  @override
  String get generalViewSwitchBehavior => '表示切り替えボタン';

  @override
  String get settingsWorkspaceMode => '使用中のワークスペース';

  @override
  String get hideHomeWorkspaceNavigation => 'ワークスペースのナビゲーションを隠す';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'ワークスペースのナビゲーションを非表示にします。メイン画面のワークスペースメニューで切り替えられます。';

  @override
  String get generalDateLabelFormat => '日付ラベルの形式';

  @override
  String get generalDateLabelFormatLocalized => '地域の形式（2026年7月）';

  @override
  String get generalDateLabelFormatSlash => 'スラッシュ区切り（2026/7）';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'ツールバーの配置';

  @override
  String get toolbarNavigationSection => 'ツールバーのナビゲーション';

  @override
  String get toolbarNavigationHiddenBehavior => '非表示の項目';

  @override
  String get toolbarNavigationRemove => '完全に非表示';

  @override
  String get toolbarNavigationMore => '「その他」に移動';

  @override
  String get toolbarNavigationReorder => 'ツールバーの項目を並べ替え';

  @override
  String get toolbarNavigationVisibility => 'ツールバーの項目を表示';

  @override
  String get toolbarNavigationTimetable => '時間割の選択';

  @override
  String get toolbarNavigationWeek => '週の選択';

  @override
  String get toolbarNavigationView => '表示の切り替え';

  @override
  String get toolbarNavigationCategory => 'カテゴリの選択';

  @override
  String get toolbarNavigationDate => '日付の選択';

  @override
  String get generalToolbarWidthPolicy => 'ツールバーの幅の配分';

  @override
  String get generalToolbarWidthContent => '自動配分';

  @override
  String get generalToolbarWidthBalanced => '均等';

  @override
  String get generalToolbarWidthCalendarPriority => 'カテゴリを優先';

  @override
  String get generalToolbarWidthDatePriority => '日付を優先';

  @override
  String get generalViewSwitchCycle => '表示を順に切り替え';

  @override
  String get generalViewSwitchMenu => '表示メニューを開く';

  @override
  String get generalViewSwitchTooltip => '表示を切り替え';

  @override
  String get generalViewSwitchMenuTooltip => '表示を選択';

  @override
  String get generalViewLongPressTodayHint => '長押しで今日に移動';

  @override
  String get generalScheduleDisplaySection => 'スケジュールの表示';

  @override
  String get generalTimeGridSection => '時間グリッド';

  @override
  String get generalPopupSection => 'ポップアップの動作';

  @override
  String get quickActionsSection => 'クイック操作';

  @override
  String get showAddCourseFab => '授業追加のフローティングボタンを表示';

  @override
  String get showAddCourseFabHint => '時間割の右下にある授業追加ボタンの表示を切り替えます。';

  @override
  String get showAddEventFab => '予定追加のフローティングボタンを表示';

  @override
  String get showAddEventFabHint => 'スケジュールの右下にある予定追加ボタンの表示を切り替えます。';

  @override
  String get enableLongPressAddCourse => '空白のグリッドを長押しして授業を追加';

  @override
  String get enableLongPressAddCourseHint => '時間割の空白部分を長押しすると授業を追加できます。';

  @override
  String get enableLongPressAddEvent => '空白のグリッドを長押しして予定を追加';

  @override
  String get enableLongPressAddEventHint =>
      '日表示または週表示の時間グリッドの空白部分を長押しすると予定を追加できます。';

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
  String get developerNotificationDiagnostics => '通知の診断';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Android の通知配信状態の確認、既存のリマインダー計画の再構築、Sked の通常の通知サービスを使った安全なテスト通知の送信を行います。';

  @override
  String get developerNotificationUnsupported => '通知の診断は Android でのみ利用できます。';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      '予定の通知管理が開始すると、通知の診断を利用できます。';

  @override
  String get developerNotificationRefresh => '診断情報を更新';

  @override
  String get developerNotificationSystemStatus => 'システムの通知権限';

  @override
  String get developerNotificationPermissionAllowed => '許可済み';

  @override
  String get developerNotificationPermissionBlocked => 'ブロック済み';

  @override
  String get developerNotificationExactAlarm => '正確なアラーム';

  @override
  String get developerNotificationExactAlarmAllowed => '許可済み';

  @override
  String get developerNotificationExactAlarmBlocked => '許可されていません';

  @override
  String get developerNotificationPlan => '予定の通知計画';

  @override
  String get developerNotificationCoverage => 'リマインダーの予約状況';

  @override
  String get developerNotificationCoverageReady =>
      '回数が有限の既知のリマインダーはすべて直接予約済みです';

  @override
  String get developerNotificationCoverageRenewable =>
      '繰り返しのリマインダーは可能な限り継続して再予約します';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      '直接予約の上限に達しました。以降のリマインダーは可能な限り再予約します';

  @override
  String get developerNotificationCoverageBlocked => '正確に配信するための条件を満たしていません';

  @override
  String get developerNotificationCoverageFailed => '直近のリマインダー同期に失敗しました';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '直接予約 $scheduled 件／上限 $capacity 件';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '予約済み $scheduled 件、計画済み $planned 件';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return '前回のエラー：$message';
  }

  @override
  String get developerNotificationRunMaintenance => '通知計画を再構築';

  @override
  String get developerNotificationMaintenanceComplete => '通知計画を再構築しました。';

  @override
  String get developerNotificationTestChannel => 'テストチャンネル';

  @override
  String get developerNotificationTestCourse => '授業のリマインダー';

  @override
  String get developerNotificationTestSchedule => '予定のリマインダー';

  @override
  String get developerNotificationImmediateTest => '今すぐテスト通知を送信';

  @override
  String get developerNotificationThirtySecondTest => '30秒後のバックグラウンドテストを予約';

  @override
  String get developerNotificationImmediateQueued => '即時テスト通知を送信しました。';

  @override
  String get developerNotificationThirtySecondQueued =>
      '30秒後のバックグラウンドテストを予約しました。';

  @override
  String get developerNotificationAppSwitch => 'アプリのリマインダースイッチ';

  @override
  String get developerNotificationAppSwitchEnabled => '通常のリマインダーは有効です';

  @override
  String get developerNotificationAppSwitchDisabled =>
      '通常のリマインダーは無効です。開発者向けテストは実行できます';

  @override
  String get developerNotificationTimeZone => 'ローカルタイムゾーン';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'まだ作成されていません。開発者向けテストを実行すると作成されます。';

  @override
  String get developerNotificationChannelEnabledState => '有効';

  @override
  String get developerNotificationChannelBlockedState => 'ブロック済み';

  @override
  String developerNotificationChannelImportance(int importance) {
    return '重要度：$importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable => '重要度を取得できません';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '待機中 $pending 件／表示中 $active 件';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'ネイティブ側の最終表示：$time';
  }

  @override
  String get developerNotificationNoDiagnostic => '再調整の記録はまだありません。';

  @override
  String get developerNotificationNextReminder => '次の通常のリマインダー';

  @override
  String get developerNotificationNoPendingReminder => '現在の計画に今後のリマインダーはありません';

  @override
  String get developerNotificationNextMaintenance => '次回のメンテナンス';

  @override
  String get developerNotificationNextRenewal => '次回の再予約試行';

  @override
  String get developerNotificationNoMaintenance => '未予約';

  @override
  String get developerNotificationTruncation => '計画の上限による省略';

  @override
  String developerNotificationTruncationCount(int count) {
    return '計画の上限により $count 件を省略';
  }

  @override
  String get developerNotificationLastReconciliation => '直近の再調整';

  @override
  String get developerNotificationLastSynchronization => '直近のリマインダー同期';

  @override
  String get developerNotificationLateRecovery => '時刻を過ぎたリマインダーの復旧';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '予定時刻を過ぎた $count 件のリマインダーを復旧して配信しました';
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
  String get developerNotificationReconcileOriginForeground => 'フォアグラウンド';

  @override
  String get developerNotificationReconcileOriginBackground => 'バックグラウンド';

  @override
  String get developerNotificationReconcileModeAuthoritative => '全体の再計算';

  @override
  String get developerNotificationReconcileModeMaintenance => 'メンテナンス';

  @override
  String get developerNotificationReconcileModeRecovery => '復旧';

  @override
  String get developerNotificationRunRecovery => 'リマインダーを復旧';

  @override
  String get developerNotificationRecoveryComplete => 'リマインダーの復旧が完了しました';

  @override
  String get developerNotificationReconcileResultSuccess => '成功';

  @override
  String get developerNotificationReconcileResultSkipped => 'スキップ済み';

  @override
  String get developerNotificationReconcileResultBlocked =>
      '正確な配信に必要な条件をすべて満たすまで予約しません';

  @override
  String get developerNotificationReconcileResultFailed => '失敗';

  @override
  String get developerNotificationBackgroundLimits => 'メーカーによるバックグラウンド制限';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'メーカーのバックグラウンド制限が配信に影響する場合があります。';

  @override
  String get developerNotificationAutostart => 'メーカー独自のバックグラウンド起動';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'メーカー：$vendor。メーカー設定へのリンクがあります。Android ではその許可状態を取得できません。';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'メーカー：$vendor。代わりにアプリの詳細画面を使用します。Android ではその許可状態を取得できません。';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'メーカー独自のバックグラウンド設定を開く方法がありません。';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return '最後に開いた画面：$target';
  }

  @override
  String get developerNotificationAutostartTargetVendor => 'メーカー設定';

  @override
  String get developerNotificationAutostartTargetApplicationDetails => 'アプリの詳細';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'なし';

  @override
  String get developerNotificationRebootBoundaryTitle => '再起動後の復旧の制約';

  @override
  String get developerNotificationRebootBoundary =>
      '復旧は最初のロック解除後に始まります。強制停止されたアプリは自動起動できません。';

  @override
  String get developerNotificationTestChecking => '通知の状態を確認中のため、テストは利用できません。';

  @override
  String get developerNotificationTestBlockedSystem =>
      'システムの通知がブロックされているため、テストは利用できません。';

  @override
  String get developerNotificationTestBlockedChannel =>
      '選択した通知チャンネルがブロックされているため、テストは利用できません。';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Windows の通知設定で管理されます';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Windows では対象外です';

  @override
  String get developerNotificationWindowsIdentity => 'Windows パッケージ ID';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX パッケージ ID を確認済みです。表示中の通知を取り消せます';

  @override
  String get developerNotificationWindowsMsixRequired =>
      '表示中の通知を確実に取り消すには MSIX 版をインストールしてください';

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
  String get notificationSettingsSection => 'リマインダーと通知';

  @override
  String get notificationCoverage => 'リマインダーの予約状況';

  @override
  String get notificationCoverageRenewable =>
      '終了日を指定していない繰り返し予定は、バックグラウンドで再予約して長期的な通知を維持します。';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android が直接予約できるリマインダーは最大 $capacity 件です。それ以降の通知は事前に再予約を試みます。';
  }

  @override
  String get notificationSettingsEnabled => 'リマインダーと通知を有効にする';

  @override
  String get notificationSettingsEnabledHint =>
      'リマインダーを設定した項目のみ通知を予約します。既定値を使う授業については、以下で授業の既定のリマインダーを設定してください。';

  @override
  String get notificationPrecisionLimitations =>
      '通知はシステム権限とバックグラウンド実行に依存します。電源オフ、時刻の変更、システム制限により遅れる場合があります。';

  @override
  String get notificationSettingsEnabledSummary => '有効';

  @override
  String get notificationSettingsDisabledSummary => '無効';

  @override
  String get notificationDefaultsSection => '既定のリマインダー';

  @override
  String get notificationCourseDefaultReminder => '授業の既定のリマインダー';

  @override
  String get notificationGeneralDefaultReminder => '予定の既定のリマインダー';

  @override
  String get notificationReminderOff => '通知しない';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes 分前';
  }

  @override
  String get notificationPermission => '通知の権限';

  @override
  String get notificationPermissionGranted => 'システムで許可済み';

  @override
  String get notificationPermissionDenied => 'システムでブロック済み';

  @override
  String get notificationPermissionChecking => '権限を確認中…';

  @override
  String get notificationPermissionRequest => '権限をリクエスト';

  @override
  String get notificationPermissionOpenSettings => 'システム設定を開く';

  @override
  String get notificationPermissionRequestFailed =>
      '通知の権限を確認できませんでした。再試行してください。';

  @override
  String get notificationExactAlarm => '正確なアラームの権限';

  @override
  String get notificationExactAlarmAllowed => 'システムで許可済み';

  @override
  String get notificationExactAlarmRequired => '正確な時刻に通知するために必要です';

  @override
  String get notificationExactAlarmRequest => '正確なアラームを許可';

  @override
  String get notificationBatteryOptimization => 'バッテリーの最適化';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Android のバッテリー最適化の対象外に設定済み';

  @override
  String get notificationBatteryOptimizationRequired =>
      '正確な通知には Android のバッテリー最適化の対象外に設定する必要があります';

  @override
  String get notificationBatteryOptimizationRequest => 'バッテリー最適化の設定を開く';

  @override
  String get notificationAutostart => 'メーカー独自のバックグラウンド起動';

  @override
  String get notificationAutostartVendorHint =>
      '再起動後にリマインダーを復旧できるよう、自動起動またはバックグラウンド動作を許可してください。';

  @override
  String get notificationAutostartFallbackHint =>
      'Sked のアプリ詳細画面でバックグラウンド動作を許可してください。このメーカー独自の設定は Android から確認できません。';

  @override
  String get notificationAutostartUnavailable =>
      'メーカーの設定画面が見つかりません。Sked のアプリ詳細画面を手動で確認してください。';

  @override
  String get notificationAutostartRequest => 'メーカーのバックグラウンド設定を開く';

  @override
  String get notificationAutostartOpenFailed =>
      'メーカーのバックグラウンド設定を開けませんでした。Sked のアプリ詳細画面を手動で確認してください。';

  @override
  String get notificationLockScreenTitles => 'ロック画面にタイトルを表示';

  @override
  String get notificationLockScreenTitlesHint => 'オフにすると、ロック画面に通知の詳細を表示しません。';

  @override
  String get notificationWidgets => 'ホーム画面ウィジェット';

  @override
  String get notificationWidgetsDesc => 'Sked ウィジェットを更新し、ホーム画面への追加方法を確認します。';

  @override
  String get notificationWidgetsDialogTitle => 'Sked ウィジェットを追加';

  @override
  String get notificationWidgetsDialogMessage =>
      '端末のホーム画面の空白部分を長押しし、「ウィジェット」から Sked ウィジェットを追加してください。今後の授業や予定を表示できます。';

  @override
  String get notificationWidgetsRefresh => 'ウィジェットを更新';

  @override
  String get notificationWidgetsRefreshed => 'ウィジェットを更新しました';

  @override
  String get notificationPlatformUnsupported => 'このプラットフォームはネイティブ通知を提供していません。';

  @override
  String get workspaceFeatures => '機能管理';

  @override
  String get workspaceBoth => '時間割と予定';

  @override
  String get workspaceOnlyStudent => '時間割のみ';

  @override
  String get workspaceOnlyGeneral => '予定のみ';

  @override
  String get workspaceDisableTitle => 'このワークスペースを無効にしますか？';

  @override
  String get workspaceDisableMessage =>
      'データと設定は保持されます。ここで再び有効にするまで、関連機能とリマインダーは停止します。';

  @override
  String get workspaceEnableHint => '使う機能を選択してください。少なくとも1つは有効にする必要があります。';

  @override
  String get workspaceLastRequired => '少なくとも1つのワークスペースを有効にしてください。';

  @override
  String get workspaceReminderCleanupFailed =>
      'ワークスペースは無効ですが、リマインダーの削除が完了していません。通知の復旧を再試行してください。';

  @override
  String get settingsSearch => '設定を検索';

  @override
  String get settingsNoResults => '一致する設定はありません';

  @override
  String get settingsDataPrivacy => 'データとプライバシー';

  @override
  String get workspacePreferences => '表示と操作';

  @override
  String get workspaceManage => '管理';

  @override
  String get selectedDayAgenda => '選択した日の予定';

  @override
  String get notificationTroubleshooting => '権限とトラブルシューティング';

  @override
  String get settingsConnection => '接続';

  @override
  String get settingsAdvanced => '詳細設定';

  @override
  String get unsavedChangesMessage => '未保存の変更があります。破棄して終了しますか？';

  @override
  String get backupWorkspaceSelection => '完全バックアップにはデータとワークスペースの有効状態が含まれます。';

  @override
  String get assistantLayoutPreview => 'AI · レイアウトのプレビュー';

  @override
  String get assistantSelectionContext => '現在の選択内容をコンテキストとして使用します';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'メッセージの下書き';

  @override
  String get assistantPreviewNoSend => 'レイアウトのプレビューのみです。送信や変更は行いません。';

  @override
  String get resizePanel => 'パネルのサイズを変更';

  @override
  String get minimizeWindow => '最小化';

  @override
  String get maximizeWindow => '最大化';

  @override
  String get restoreWindow => '元のサイズに戻す';

  @override
  String get closeWindow => 'ウィンドウを閉じる';

  @override
  String get courseSystemReminder => 'システムリマインダー';

  @override
  String courseReminderInherit(String reminder) {
    return '既定値を使用（$reminder）';
  }

  @override
  String get courseReminderMasterOff =>
      '通知設定でシステムリマインダーが無効になっています。この授業の設定は保存できます。';

  @override
  String get courseReminderDefaultOff =>
      '授業の既定のリマインダーが未設定です。ここで個別に設定するか、通知設定で既定値を設定してください。';

  @override
  String get courseReminderDeliveryHint =>
      'この設定は授業と一緒に保存されます。実際の配信は、システムの通知権限やバックグラウンド制限に左右されます。';

  @override
  String get courseReminderPermissionUnknown =>
      'システムの通知状態は未確認です。リマインダーを利用する前に通知設定を確認してください。';

  @override
  String get courseReminderMinutesLabel => '授業開始の何分前に通知するか';

  @override
  String get exportAction => 'エクスポート';

  @override
  String get datePickerSelectWeek => '週を選択';

  @override
  String get datePickerSelectMonth => '月を選択';

  @override
  String get generalDateLabelFormatDescription =>
      'デスクトップと小さい画面の日付ナビゲーションに適用します。';

  @override
  String get dateRangeTitle => '期間を選択';

  @override
  String get dateRangeCustom => 'カスタム';

  @override
  String get dateRangeChooseStart => '開始日を選択してください';

  @override
  String get dateRangeChooseEnd => '終了日を選択してください';

  @override
  String get dateRangeLimit => '開始日と終了日を含めて1～14日を選択してください。';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 日',
      one: '1 日',
    );
    return 'カスタム · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'ホイールで選択';

  @override
  String get courseReminderUseDefault => '既定値を使用';

  @override
  String get courseReminderInvalidMinutes => '0以上の整数で分数を入力してください。';

  @override
  String get generalCustomColumnWidth => 'カスタム表示の列幅';

  @override
  String get generalCustomColumnWidthAuto => '自動';

  @override
  String get generalCustomColumnWidthManual => '最小幅';

  @override
  String get generalCustomColumnWidthMinimum => '1日あたりの最小幅';

  @override
  String get generalCustomColumnWidthHint =>
      'すべての日付で同じ最小幅を使用します。空き領域を均等に埋め、収まらない場合は横スクロールになります。カスタム表示にのみ適用されます。';

  @override
  String get settingsAppearanceLanguage => '外観と言語';

  @override
  String get settingsAppearanceDetails => '色と輪郭';

  @override
  String get monthNoEvents => 'この日の予定はありません';

  @override
  String get settingsOverview => '概要';

  @override
  String get settingsThemeTarget => 'テーマの適用先';

  @override
  String get settingsColorMode => 'カラーモード';

  @override
  String get settingsNotificationPreferences => 'リマインダー設定';

  @override
  String get settingsNotificationPreferencesSummary => '既定の通知時刻、権限、配信の信頼性';

  @override
  String get settingsFeaturesSummary => 'ワークスペースとナビゲーション';

  @override
  String get settingsPrivacySummary => 'プライバシーポリシーとローカルデータの消去';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 時限',
      one: '1 時限',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => '時限';

  @override
  String get periodTimesDurationColumn => '長さ';

  @override
  String get periodTimesGapColumn => '休憩';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes 分';
  }

  @override
  String get periodTimesSavePending => '保存待ち…';

  @override
  String get periodTimesSaveFailed => '未保存 · 保存に失敗しました';

  @override
  String get periodTimesInvalidStatus => '未保存 · 強調表示された時刻を修正してください';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      '前回の保存が取り消されたかどうかを確認できませんでした。書き込みを停止し、復元用のコピーを保持しています。ストレージを確認してから、読み込みを再試行してください。';

  @override
  String get settingsPanelDisplayMode => 'パネルの表示方法';

  @override
  String get settingsPanelDisplayModeGlobal => '時間割と予定で共通';

  @override
  String get settingsPanelDisplayOverlay => '重ねて表示';

  @override
  String get settingsPanelDisplaySideBySide => '並べて表示';

  @override
  String get settingsPanelDisplayAutomatic => '自動';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'カレンダーの幅を変えず、右側に重ねて表示します。';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      '並べて表示を優先し、カレンダーが狭すぎる場合のみ重ねて表示します。';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'カレンダーを読みやすい幅で表示できる場合は並べ、それ以外は重ねて表示します。';

  @override
  String get toolbarNavigationEssentialHint =>
      'ツールバーの「設定」または「ワークスペース」をオフにすると、削除せずに「その他」へ移動します。必須の操作が入っている間は「その他」を隠せません。ワークスペースの切り替えは、下部ナビゲーションが非表示で、複数のワークスペースが有効な場合にのみ表示されます。';

  @override
  String get reminderEnded => '終了済み';

  @override
  String get reminderAutoCloseHint => '10秒後に閉じます。操作すると開いたままになります。';

  @override
  String get showReminderIndependently => '独立して開く';

  @override
  String get categoryManagerTitle => 'カテゴリを管理';

  @override
  String get categoryHidden => '非表示';

  @override
  String get categoryShowOnCalendar => 'カレンダーに表示';

  @override
  String get categoryHideOnCalendar => 'カレンダーで非表示';

  @override
  String get categoryEditColor => 'カテゴリの色を変更';

  @override
  String get categoryThemePalette => 'テーマの配色';

  @override
  String get categoryCustomColor => 'カスタム';

  @override
  String get colorHexInvalid => '6桁の16進数で色を入力してください。';

  @override
  String categoryColorSlot(int number) {
    return 'テーマの色 $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay => 'ストアへの更新の反映が遅れる場合があります。提供状況はストアのページで確認してください。';

  @override
  String get storePrereleaseNotice =>
      'プレビュー版の更新通知を受け取っても、ストアのテストプログラムには登録されません。';

  @override
  String get updateFoundTitle => '新しいバージョンがあります';

  @override
  String get updateNoNotes => 'このバージョンの更新内容は提供されていません。';

  @override
  String get updateLater => '後で';

  @override
  String get updateRetry => '再試行';

  @override
  String get updatePrerelease => 'プレビュー版';

  @override
  String get updateNetworkFailure => '更新を確認できませんでした。接続を確認して再試行してください。';

  @override
  String updateNoNewerVersion(String version) {
    return '新しいバージョンは見つかりませんでした（現在：$version）';
  }

  @override
  String get backupRestoreInProgressTitle => 'バックアップを復元中…';

  @override
  String get backupRestoreInProgressMessage =>
      '復元が完了するまで、データや設定は変更できません。引き続き内容を閲覧できます。';
}
