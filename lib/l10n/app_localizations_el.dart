// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class AppLocalizationsEl extends AppLocalizations {
  AppLocalizationsEl([String locale = 'el']) : super(locale);

  @override
  String get appTitle => 'Συντάκτης';

  @override
  String weekLabel(int week) {
    return 'Εβδομάδα $week';
  }

  @override
  String get addCourse => 'Προσθήκη μαθήματος';

  @override
  String get settings => 'Ρυθμίσεις';

  @override
  String get multiTimetableSwitch => 'Αλλαγή προγραμμάτων';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Τρέχον χρονοδιάγραμμα · $weeks εβδομάδες';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Πατήστε για να αλλάξετε · $weeks εβδομάδες';
  }

  @override
  String get editTimetable => 'Επεξεργασία προγράμματος';

  @override
  String get createTimetable => 'Νέο χρονοδιάγραμμα';

  @override
  String get jumpToWeek => 'Μετάβαση στην εβδομάδα';

  @override
  String get timetable => 'Χρονολόγιο';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Όνομα προγράμματος';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Συνολικές εβδομάδες';

  @override
  String get delete => 'Διαγραφή';

  @override
  String get cancel => 'Ακύρωση';

  @override
  String get save => 'Αποθήκευση';

  @override
  String get deleteTimetableTitle => 'Διαγραφή προγράμματος';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Διαγραφή \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Δεν υπάρχει ακόμα χρονοδιάγραμμα';

  @override
  String get noTimetableMessage =>
      'Δημιουργήστε ένα χρονοδιάγραμμα ή εισάγετε ένα από ένα αρχείο JSON.';

  @override
  String get importTimetable => 'Εισαγωγή προγράμματος';

  @override
  String get courseName => 'Όνομα μαθήματος';

  @override
  String get location => 'Τοποθεσία';

  @override
  String get dayOfWeek => 'Ημέρα';

  @override
  String get semesterWeeks => 'Εβδομάδες';

  @override
  String get startTime => 'Χρόνος έναρξης';

  @override
  String get endTime => 'Χρόνος λήξης';

  @override
  String get linkedPeriods => 'Συνδεδεμένες περιόδους';

  @override
  String get linkedPeriodsUnmatched =>
      'Καμία περίοδος δεν ταιριάζει για την τρέχουσα ώρα. Πατήστε για να επιλέξετε με μη αυτόματο τρόπο.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Περίοδος $start-$end';
  }

  @override
  String get teacherName => 'Δάσκαλος';

  @override
  String get credits => 'Πιστώσεις';

  @override
  String get remarks => 'Παρατηρήσεις';

  @override
  String get customFields => 'Προσαρμοσμένα πεδία';

  @override
  String get customFieldsHint => 'Ένα ανά γραμμή, μορφή: κλειδί: τιμή';

  @override
  String get more => 'Περισσότερα';

  @override
  String get selectDayOfWeek => 'Επιλέξτε ημέρα';

  @override
  String get selectSemesterWeeks => 'Επιλέξτε εβδομάδες';

  @override
  String get selectAll => 'Επιλέξτε όλα';

  @override
  String get clear => 'Καθαρισμός';

  @override
  String get confirm => 'Επιβεβαίωση';

  @override
  String get selectLinkedPeriods => 'Επιλέξτε συνδεδεμένες περιόδους';

  @override
  String get addCourseTitle => 'Προσθήκη μαθήματος';

  @override
  String get editCourseTitle => 'Επεξεργασία μαθήματος';

  @override
  String get editCourseTooltip => 'Επεξεργασία μαθήματος';

  @override
  String get place => 'Τοποθεσία';

  @override
  String get time => 'Χρόνος';

  @override
  String get notFilled => 'Μη συμπληρώνεται';

  @override
  String get none => 'Καμία';

  @override
  String get conflictCourses => 'Συγκριτικά μαθήματα';

  @override
  String get locationNotFilled => 'Τοποθεσία δεν συμπληρώνεται';

  @override
  String get setAsDisplayed => 'Ορισμός ως εμφανίζεται';

  @override
  String get editThisCourse => 'Επεξεργαστείτε αυτό το μάθημα';

  @override
  String get settingsTitle => 'Ρυθμίσεις';

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
  String get noTimetableSettings =>
      'Δεν υπάρχει διαθέσιμο χρονοδιάγραμμα για τις ρυθμίσεις.';

  @override
  String get semesterStartDate => 'Ημερομηνία έναρξης του εξάμηνου';

  @override
  String get periodTimeSets => 'Καθορισμένος χρόνος περιόδου';

  @override
  String get noPeriodTimeAvailable =>
      'Δεν έχει οριστεί διαθέσιμος χρόνος περιόδου';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count περιόδους';
  }

  @override
  String get coursePopupDismissSetting =>
      'Επιτρέψτε το εξωτερικό πατήμα για να κλείσετε το αναδυόμενο παράθυρο μαθήματος';

  @override
  String get coursePopupDismissSettingHint =>
      'Η απενεργοποίηση αυτής της λειτουργίας απενεργοποιεί επίσης την απόλυση με σάρωση προς τα κάτω.';

  @override
  String get preserveTimetableGaps => 'Διατήρηση κενών στο χρονοδιάγραμμα';

  @override
  String get preserveTimetableGapsHint =>
      'Όταν είναι εκτός λειτουργίας, τα κενά για το μεσημεριανό και το διάλειμμα καταρρέουν έτσι ώστε αργότερα τα μαθήματα να κινούνται προς τα πάνω.';

  @override
  String get showPastEndedCourses => 'Εμφάνιση προηγούμενων μαθημάτων';

  @override
  String get showPastEndedCoursesHint =>
      'Δείξτε μαθήματα που έχουν ήδη τελειώσει από την πραγματική τρέχουσα εβδομάδα με ένα πιο ανοιχτό γκρι στυλ.';

  @override
  String get showFutureCourses => 'Εμφάνιση μελλοντικών μαθημάτων';

  @override
  String get showFutureCoursesHint =>
      'Εμφάνιση μαθημάτων που δεν είναι ενεργά αυτή την εβδομάδα, αλλά θα εμφανιστούν στις επόμενες εβδομάδες με γκρίζο στυλ.';

  @override
  String get timetableDisplaySettings =>
      'Εμφάνιση χρονοδιαγράμματος και αλληλεπίδραση';

  @override
  String get timetableDisplaySettingsDesc =>
      'Εμφάνιση μαθημάτων, διάταξη, χειρονομίες εβδομάδας και γρήγορη προσθήκη';

  @override
  String get showTimetableGridLines =>
      'Εμφάνιση γραμμών πλέγματος προγραμματισμού';

  @override
  String get showTimetableGridLinesHint =>
      'Ελέγξτε εάν οι οριζόντιες και κάθετες γραμμές πλέγματος είναι ορατές στο χρονοδιάγραμμα.';

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
  String get liveCourseOutlineColor => 'Χρώμα περιγράμματος μαθήματος';

  @override
  String get liveCourseOutlineColorHint =>
      'Επιλέξτε εάν τα περιγράμματα στοχεύουν στο τρέχον/επόμενο μάθημα ή σε όλα τα μαθήματα που εμφανίζονται στην τρέχουσα σελίδα.';

  @override
  String get liveCourseOutlineSettings => 'Σχεδιασμός μαθημάτων';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Ρυθμίστε εάν το περιγράμμα είναι ενεργοποιημένο, τι στοχεύει, εάν ακολουθεί το χρώμα του θέματος και το αποτελεσματικό χρώμα του περιγράμματος.';

  @override
  String get liveCourseOutlineEnabled => 'Ενεργοποίηση περιγράμματος';

  @override
  String get liveCourseOutlineFollowTheme => 'Ακολουθήστε το χρώμα του θέματος';

  @override
  String get liveCourseOutlineTarget => 'Στόχος περιγραφής';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Τρέχον/επόμενο μάθημα';

  @override
  String get liveCourseOutlineTargetAllDisplayed =>
      'Όλα τα μαθήματα που εμφανίζονται';

  @override
  String get liveCourseOutlineEffectiveColor => 'Αποτελεσματικό χρώμα';

  @override
  String get liveCourseOutlineCustomColor =>
      'Προσαρμοσμένο χρώμα περιγράμματος';

  @override
  String get liveCourseOutlineWidth => 'Πλάτος περιγράμματος';

  @override
  String get outlineWidthUnit => 'Πξ';

  @override
  String get language => 'Γλώσσα';

  @override
  String get languagePageDescription =>
      'Επιλέξτε μία από τις γλώσσες που είναι πραγματικά διαθέσιμη στην εφαρμογή.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'Αγγλικά';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Απάντηση API';

  @override
  String get theme => 'Θέμα';

  @override
  String get themeFollowSystem => 'Ακολουθήστε το σύστημα';

  @override
  String get themeLight => 'Φως';

  @override
  String get themeDark => 'Σκοτεινό';

  @override
  String get themeColor => 'Χρώμα θέματος';

  @override
  String get themeColorModeSingle => 'Ενιαίο χρώμα θέματος';

  @override
  String get themeColorModeColorful => 'Πολύχρωμη';

  @override
  String get themeColorUiColors => 'Χρώματα UI';

  @override
  String get themeColorCourseColors => 'Χρώματα μαθήματος';

  @override
  String get themeColorPrimary => 'πρωτογενής';

  @override
  String get themeColorSecondary => 'Δευτεροβάθμια';

  @override
  String get themeColorTertiary => 'Τρίτου';

  @override
  String get themeColorCourseText => 'Κείμενο μαθημάτων';

  @override
  String get themeColorCourseTextAuto => 'Αυτόματο';

  @override
  String get themeColorCourseTextCustom => 'Προσαρμοσμένο χρώμα';

  @override
  String get themeColorCourseColorsEmpty =>
      'Τα χρώματα των μαθημάτων θα δημιουργηθούν μετά την εισαγωγή ενός προγράμματος.';

  @override
  String get themeCustomColor => 'Προσαρμοσμένο χρώμα';

  @override
  String get themeApplyCustomColor => 'Εφαρμόστε χρώμα';

  @override
  String get themeApplySettings => 'Εφαρμογή ρυθμίσεων';

  @override
  String get dataImportExport => 'Εισαγωγή και εξαγωγή δεδομένων';

  @override
  String get dataImportExportDesc =>
      'Εισαγωγή πλήρων δεδομένων ή ενιαίων προγραμμάτων ή εξαγωγή τρέχοντος/όλων των προγραμμάτων.';

  @override
  String get appBackupTitle => 'Αντίγραφο ασφαλείας και επαναφορά εφαρμογής';

  @override
  String get appBackupSubtitle =>
      'Δημιουργήστε αντίγραφα ασφαλείας ή επαναφέρετε ωρολόγια προγράμματα, προγράμματα, ρυθμίσεις και σχολικούς ιστότοπους. Τα κλειδιά API δεν περιλαμβάνονται.';

  @override
  String get appBackupSheetSubtitle =>
      'Η πλήρης επαναφορά αντικαθιστά τα τρέχοντα δεδομένα της εφαρμογής. Τα κλειδιά AI API αποθηκεύονται σε ασφαλή αποθήκευση και δεν γράφονται στα αρχεία αντιγράφων ασφαλείας.';

  @override
  String get restoreBackupFileTitle => 'Επαναφορά από αρχείο JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Επιλέξτε ένα πλήρες αρχείο αντιγράφου ασφαλείας Sked. Θα επιβεβαιώσετε πριν από την επαναφορά.';

  @override
  String get restoreBackupTextTitle => 'Επικόλληση JSON αντιγράφου ασφαλείας';

  @override
  String get restoreBackupTextSubtitle =>
      'Επικολλήστε ένα πλήρες αντίγραφο ασφαλείας και επαναφέρετε τα τρέχοντα δεδομένα της εφαρμογής.';

  @override
  String get shareBackupTitle => 'Κοινή χρήση αρχείου αντιγράφου ασφαλείας';

  @override
  String get shareBackupSubtitle =>
      'Εξαγωγή όλων των δεδομένων της εφαρμογής ως JSON. Τα κλειδιά API εξαιρούνται.';

  @override
  String get saveBackupTitle => 'Αποθήκευση αρχείου αντιγράφου ασφαλείας';

  @override
  String get saveBackupSubtitle =>
      'Αποθηκεύστε ένα πλήρες αντίγραφο ασφαλείας της εφαρμογής σε τοπικό αρχείο.';

  @override
  String get copyBackupTitle => 'Αντιγραφή κειμένου αντιγράφου ασφαλείας';

  @override
  String get copyBackupSubtitle =>
      'Εμφανίζει το πλήρες JSON του αντιγράφου ασφαλείας για αντιγραφή ή προσωρινή αποθήκευση.';

  @override
  String get restoreBackupConfirmTitle =>
      'Επαναφορά πλήρους αντιγράφου ασφαλείας;';

  @override
  String get restoreBackupConfirmMessage =>
      'Αυτό θα αντικαταστήσει όλα τα τρέχοντα ωρολόγια προγράμματα, γενικά προγράμματα, ρυθμίσεις και σχολικούς ιστότοπους. Τα κλειδιά API δεν εισάγονται από αντίγραφα ασφαλείας· εισαγάγετε ξανά το κλειδί πριν αναλύσετε ξανά ωρολόγια προγράμματα.';

  @override
  String get restoreBackupConfirmAction => 'Επαναφορά αντιγράφου ασφαλείας';

  @override
  String get restoreBackupSuccessMessage =>
      'Το πλήρες αντίγραφο ασφαλείας της εφαρμογής επαναφέρθηκε. Τα κλειδιά AI API πρέπει να εισαχθούν ξανά.';

  @override
  String get restoreBackupFailureMessage =>
      'Η επαναφορά απέτυχε. Ελέγξτε το περιεχόμενο του αντιγράφου ασφαλείας και δοκιμάστε ξανά.';

  @override
  String get openSourceLicenses => 'Άδειες ανοιχτού κώδικα';

  @override
  String get openSourceLicensesDesc =>
      'Προβολή αδειών για τις εξαρτήσεις του Flutter και τα στοιχεία ενεργητικού εικονιδίων εφαρμογών.';

  @override
  String get checkForUpdates => 'Ελέγξτε για ενημερώσεις';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Ήδη στην τελευταία έκδοση ($version)';
  }

  @override
  String get currentVersionLabel => 'Τρέχουσα έκδοση';

  @override
  String get newVersionAvailable => 'Ενημέρωση διαθέσιμη';

  @override
  String get latestVersionLabel => 'Τελευταία έκδοση';

  @override
  String get updateContentLabel => 'Λεπτομέρειες ενημέρωσης';

  @override
  String get officialWebsite => 'Επίσημη ιστοσελίδα';

  @override
  String get googlePlay => 'στο Google Play';

  @override
  String get cloudDrive => 'Δίκη Cloud';

  @override
  String get ignoreThisVersion => 'Αγνοήστε αυτή την έκδοση';

  @override
  String get openUpdatesFailed =>
      'Αδυναμία ανοίγματος του συνδέσμου ενημέρωσης';

  @override
  String get updateCheckFailedTitle => 'Ο έλεγχος ενημέρωσης απέτυχε';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Αποθήκευση GitHub';

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
  String get openGithubFailed =>
      'Αδυναμία ανοίγματος του συνδέσμου αποθήκευσης GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Αδυναμία ανοίγματος του συνδέσμου πολιτικής απορρήτου';

  @override
  String get selectPeriodTimeSet => 'Επιλέξτε χρονική περίοδο';

  @override
  String get newItem => 'Νέα';

  @override
  String get editPeriodTimeSet => 'Επεξεργασία χρονικού ορίσματος περιόδου';

  @override
  String get importTimetableFiles => 'Εισαγωγή προγράμματος';

  @override
  String get importTimetableFilesDesc =>
      'Υποστηρίζει ένα ή πολλά αρχεία προγράμματος.';

  @override
  String get importTimetableText => 'Εισαγωγή προγράμματος από κείμενο';

  @override
  String get importTimetableTextDesc =>
      'Επικολλήστε το περιεχόμενο JSON του χρονοδιαγράμματος και εισάγετε το.';

  @override
  String get shareTimetableFiles => 'Μοιραστείτε αρχεία χρονοδιαγράμματος';

  @override
  String get shareTimetableFilesDesc =>
      'Επιλέξτε ένα ή περισσότερα προγράμματα πρώτα.';

  @override
  String get saveTimetableFiles => 'Αποθήκευση αρχείων προγραμματισμού';

  @override
  String get saveTimetableFilesDesc =>
      'Επιλέξτε ένα ή περισσότερα προγράμματα πρώτα.';

  @override
  String get exportTimetableText => 'Εξαγωγή προγράμματος ως κείμενο';

  @override
  String get exportTimetableTextDesc =>
      'Επιλέξτε ένα ή περισσότερα χρονοδιάγραμμα και, στη συνέχεια, αντιγράψτε το περιεχόμενο JSON.';

  @override
  String get jsonContent => 'Περιεχόμενο JSON';

  @override
  String get pasteJsonContentHint =>
      'Επικολλήστε το περιεχόμενο JSON για εισαγωγή.';

  @override
  String get jsonContentEmpty => 'Επικολλήστε πρώτα το περιεχόμενο JSON.';

  @override
  String get copyText => 'Αντιγραφή';

  @override
  String get copiedToClipboard => 'Αντιγραφή στο πρόβλημα';

  @override
  String get share => 'Μοιραστείτε';

  @override
  String get selectTimetablesToExport => 'Επιλέξτε χρονοδιάγραμμα για εξαγωγή';

  @override
  String get selectTimetablesToImport => 'Επιλέξτε χρονοδιάγραμμα για εισαγωγή';

  @override
  String timetableCourseCount(int count) {
    return '$count μαθήματα';
  }

  @override
  String get importAction => 'Εισαγωγή';

  @override
  String get importTimetableDialogTitle => 'Εισαγωγή προγράμματος';

  @override
  String get chooseImportMethod => 'Επιλέξτε τον τρόπο εισαγωγής.';

  @override
  String get importAsNewTimetable => 'Εισαγωγή ως νέο χρονοδιάγραμμα';

  @override
  String get replaceCurrentTimetable =>
      'Αντικαταστήστε το τρέχον χρονοδιάγραμμα';

  @override
  String get importPeriodTimeSetDialogTitle =>
      'Εισαγωγή χρονικών συνόλων περιόδου';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Αυτό το αρχείο περιέχει συσκευασμένα χρονικά σύνολα περιόδου. Θέλετε να τις εισάγετε και να τις συνδέσετε;';

  @override
  String get importBundledPeriodTimeSets => 'Εισαγωγή και σύνδεση';

  @override
  String get discardBundledPeriodTimeSets => 'Απορρίψτε τα πακέτα';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Δεν υπάρχει διαθέσιμο χρονικό σύνολο περιόδου, επομένως δεν μπορούν να απορριφθούν τα συνδεδεμένα χρονικά σύνολα περιόδου.';

  @override
  String savedToPath(Object path) {
    return 'Αποθηκεύτηκε σε $path';
  }

  @override
  String get saveCancelled => 'Αποθήκευση ακυρωμένη';

  @override
  String get fileSaveRestrictedTitle => 'Αποθήκευση αρχείου περιορισμένη';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Το σύστημα δεν μπόρεσε να αποθηκεύσει το αρχείο. Μπορείτε να δοκιμάσετε ξανά ή να χρησιμοποιήσετε την κοινή χρήση.';

  @override
  String get retrySave => 'Επαναδοκιμάστε την αποθήκευση';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Ενεργοποιήστε την πρόσβαση σε αρχεία στις ρυθμίσεις του συστήματος, στη συνέχεια επιστρέψτε και δοκιμάστε ξανά την εξαγωγή.';

  @override
  String get openSettings => 'Άνοιγμα ρυθμίσεων';

  @override
  String get browserDownloadRestrictedTitle =>
      'Περιορισμένη λήψη προγράμματος περιήγησης';

  @override
  String get browserDownloadRestrictedMessage =>
      'Αυτό το πρόγραμμα περιήγησης δεν υποστηρίζει άμεση αποθήκευση σε τοπικό αρχείο. Ελέγξτε τα δικαιώματα λήψης του προγράμματος περιήγησης ή χρησιμοποιήστε την κοινή χρήση αρχείων.';

  @override
  String get switchToShare => 'Χρησιμοποιήστε την κοινή χρήση αντί';

  @override
  String get fileSaveFailedTitle => 'Αποτυχία αποθήκευσης αρχείου';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Αδύνατη η εγγραφή στην τρέχουσα διαδρομή. Ο φάκελος στόχου μπορεί να προστατεύεται, το αρχείο μπορεί να χρησιμοποιείται ή η διαδρομή μπορεί να είναι μη εγγράφιμη.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Το σύστημα δεν μπόρεσε να αποθηκεύσει το αρχείο. Μπορείτε να δοκιμάσετε ξανά, να ελέγξετε τις ρυθμίσεις του συστήματος ή να χρησιμοποιήσετε την κοινή χρήση αρχείων.';

  @override
  String get retryLater => 'Δοκιμάστε ξανά αργότερα';

  @override
  String get exportSwitchedToShare =>
      'Μετάβαση σε κοινή χρήση αρχείων για εξαγωγή';

  @override
  String get saveFailedRetry =>
      'Η αποθήκευση απέτυχε. Δοκιμάστε ξανά αργότερα.';

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
  String get appInstanceBlockedTitle => 'Το Sked είναι ήδη ανοιχτό';

  @override
  String get appInstanceBlockedMessage =>
      'Ένα άλλο παράθυρο του Sked ή μια άλλη καρτέλα του προγράμματος περιήγησης χρησιμοποιεί τα τοπικά δεδομένα σας. Κλείστε το παράθυρο ή την καρτέλα και δοκιμάστε ξανά.';

  @override
  String get appInstanceLeaseFailedTitle =>
      'Τα τοπικά δεδομένα δεν είναι διαθέσιμα';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Το Sked δεν μπόρεσε να επαληθεύσει την αποκλειστική πρόσβαση στα τοπικά δεδομένα. Τα δεδομένα σας δεν ανοίχτηκαν ούτε άλλαξαν. Ελέγξτε την πρόσβαση στον χώρο αποθήκευσης και δοκιμάστε ξανά.';

  @override
  String get savingChanges => 'Αποθήκευση αλλαγών...';

  @override
  String get showApiKey => 'Εμφάνιση κλειδιού API';

  @override
  String get hideApiKey => 'Απόκρυψη κλειδιού API';

  @override
  String get importFailedCheckContent =>
      'Η εισαγωγή απέτυχε. Ελέγξτε το περιεχόμενο του αρχείου.';

  @override
  String get noImportableTimetables =>
      'Δεν βρέθηκαν χρήσιμα χρονοδιάγραμμα στο εισαγόμενο αρχείο.';

  @override
  String importedTimetablesCount(int count) {
    return 'Εισαγόμενα χρονοδιάγραμμα $count';
  }

  @override
  String get periodTimesTitle => 'Χρόνοι περιόδου';

  @override
  String get importExport => 'Εισαγωγή και εξαγωγή';

  @override
  String get importPeriodTemplate => 'Πρότυπο περιόδου εισαγωγής';

  @override
  String get importPeriodTemplateText =>
      'Εισαγωγή προτύπου περιόδου από κείμενο';

  @override
  String get sharePeriodTemplate => 'Πρότυπο περιόδου μετοχής';

  @override
  String get saveTemplateToFile => 'Αποθήκευση του προτύπου σε αρχείο';

  @override
  String get exportPeriodTemplateText => 'Εξαγωγή προτύπου περιόδου ως κείμενο';

  @override
  String get deletePeriodTimeSet => 'Διαγραφή χρονικού ορίσματος περιόδου';

  @override
  String get periodTimeSetName => 'Όνομα ορίσματος χρονικής περιόδου';

  @override
  String get addOnePeriod => 'Προσθέστε περίοδο';

  @override
  String periodNumberLabel(int index) {
    return 'Περίοδος $index';
  }

  @override
  String get deleteThisPeriod => 'Διαγραφή αυτής της περιόδου';

  @override
  String durationMinutes(int minutes) {
    return 'Διάρκεια $minutes λεπτά';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Κλείσμα από το προηγούμενο $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'Ο χρόνος λήξης πρέπει να είναι αργότερος από τον χρόνο έναρξης';

  @override
  String get periodOverlapPrevious =>
      'Αυτή η περίοδος επικαλύπτει την προηγούμενη';

  @override
  String get periodTimesSaved => 'Αποθηκευμένοι χρόνοι περιόδου';

  @override
  String get deletePeriodTimeSetTitle => 'Διαγραφή χρονικού ορίσματος περιόδου';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Διαγραφή \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'καθορισμός τρέχουσας περιόδου';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Εισαγόμενες $count ώρες περιόδου';
  }

  @override
  String get periodFilePermissionTitle => 'Απαιτείται άδεια αρχείου';

  @override
  String get androidFilePermissionMessage =>
      'Η εξαγωγή Android απαιτεί άδεια πρόσβασης σε αρχεία. Δώστε άδεια για να συνεχίσετε την αποθήκευση.';

  @override
  String get reauthorize => 'Εγκρίνει ξανά';

  @override
  String get permissionPermanentlyDeniedTitle => 'Η άδεια αρνείται μόνιμα';

  @override
  String get permissionSettingsExportMessage =>
      'Ενεργοποιήστε την πρόσβαση σε αρχεία στις ρυθμίσεις του συστήματος, στη συνέχεια επιστρέψτε και δοκιμάστε ξανά την εξαγωγή.';

  @override
  String get privacyPolicyTitle => 'Πολιτική Απορρήτου';

  @override
  String get privacyPolicyEntryDesc =>
      'Μάθετε πώς η εφαρμογή χειρίζεται την τοπική αποθήκευση, τη διαμόρφωση του σχολείου, την εισαγωγή/εξαγωγή αρχείων, την ανάλυση ιστοσελίδων και τους εξωτερικούς συνδέσμους.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Αποδεκτή έκδοση: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Το Sked είναι ένα εργαλείο χρονοδιαγραμμάτων που δίνει προτεραιότητα στην τοπική αποθήκευση. Τα χρονοδιαγράμματα, τα σύνολα χρονικών περιόδων και η διαμόρφωση του σχολικού ιστότοπου αποθηκεύονται μόνο στη συσκευή σας ή στο πρόγραμμα περιήγησής σας και δεν ανεβαίνουν ποτέ αυτόματα. Η εφαρμογή επεξεργάζεται δεδομένα μόνο όταν ενεργοποιείτε ρητά ενέργειες όπως εισαγωγή, ανάλυση ιστοσελίδας, κοινή χρήση ή άνοιγμα εξωτερικών συνδέσμων. Η πλήρης πολιτική απορρήτου είναι διαθέσιμη online.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Τοπική αποθήκευση';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Εισαγωγή και εξαγωγή';

  @override
  String get privacyPolicyImportExportBody =>
      'Η εφαρμογή διαβάζει ή γράφει αρχεία JSON χρονοδιαγράμματος, αρχεία JSON σχολικής τοποθεσίας και αρχεία προτύπων περιόδων μόνο όταν επιλέξετε ρητά ένα αρχείο ή ξεκινήσετε μια ενέργεια εξαγωγής. Η εισαγωγή αυτών των αρχείων είναι μια τοπική λειτουργία εκτός εάν επιλέξετε επίσης την ανάλυση ιστοσελίδας. Η λήψη μιας προσαρμοσμένης λίστας μοντέλων είναι επίσης μια ρητή ενέργεια δικτύου και επικοινωνεί μόνο με το προσαρμοσμένο τελικό σημείο που έχετε διαμορφώσει.';

  @override
  String get privacyPolicySharingTitle => 'Κοινή χρήση';

  @override
  String get privacyPolicySharingBody =>
      'Όταν χρησιμοποιείτε ρητά την κοινή χρήση, η εφαρμογή μεταδίδει το εξαγωγμένο αρχείο στο φύλλο κοινής χρήσης του συστήματος ή στην εφαρμογή στόχου που επιλέγετε. Ο τρόπος διαχείρισης αυτού του αρχείου στη συνέχεια εξαρτάται από την εφαρμογή ή την υπηρεσία στόχου που επιλέξατε.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Εξωτερικοί συνδέσμοι';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Όταν ανοίγετε εξωτερικούς συνδέσμους, όπως το αποθήκευση GitHub, η εφαρμογή μεταδίδει την ενέργεια στο πρόγραμμα περιήγησής σας ή σε άλλη εξωτερική εφαρμογή. Ο χειρισμός δεδομένων μετά το σημείο αυτό διέπεται από το τρίτο μέρος που ανοίγετε.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Τι δεν συλλέγει η εφαρμογή';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Η εφαρμογή δεν απαιτεί λογαριασμό Sked και δεν ενεργοποιεί αναλύσεις, αναγνωριστικά διαφήμισης ή αντιγραφή ασφαλείας στο cloud. Επίσης δεν παρέχει ένα ειδικό πεδίο για τη συλλογή κωδικών πρόσβασης λογαριασμού σχολείου. Εάν συνδεθείτε σε έναν ιστότοπο σχολείου μέσα στην εφαρμογή, αυτή η αλληλεπίδραση συμβαίνει στη σελίδα του σχολείου που ανοίξατε.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Ανάλυση ιστοσελίδας';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Όταν χρησιμοποιείτε εισαγωγή σχολικής ιστοσελίδας ή ανάλυση επικολλημένου κειμένου ωρολογίου προγράμματος / HTML, η εφαρμογή πρώτα προετοιμάζει και καθαρίζει το περιεχόμενο τοπικά και έπειτα στέλνει το υποβληθέν κείμενο προγράμματος, κείμενο σελίδας ή περιεχόμενο HTML, τον προαιρετικό τίτλο και το URL της σελίδας, την τρέχουσα γλώσσα της εφαρμογής και το περιεχόμενο οδηγιών του αναλυτή στο συμβατό με OpenAI endpoint που ρυθμίσατε. Η λήψη της λίστας μοντέλων ζητά επίσης το ίδιο endpoint. Το Sked δεν παρέχει ενσωματωμένο endpoint ανάλυσης και δεν στέλνει αιτήματα ανάλυσης σε backend αναλυτή προγραμμάτων που ελέγχεται από τον προγραμματιστή. Το προσαρμοσμένο endpoint και τυχόν ανάντη υπηρεσίες μπορεί να αποθηκεύουν, προωθούν, περιορίζουν, διαγράφουν ή επεξεργάζονται με άλλο τρόπο τα δεδομένα σύμφωνα με τους κανόνες του παρόχου υπηρεσίας που επιλέγετε. Αν χρησιμοποιείτε http:// Base URL, χρησιμοποιήστε το μόνο σε αξιόπιστες συσκευές, δίκτυα και υπηρεσίες endpoint, επειδή το περιεχόμενο και τα API keys μπορεί να μην προστατεύονται με κρυπτογράφηση μεταφοράς.';

  @override
  String get privacyPolicyUpdatesTitle => 'Ενημερώσεις πολιτικής';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Η τρέχουσα έκδοση της πολιτικής απορρήτου είναι $version. Εάν μια μεταγενέστερη έκδοση αλλάξει τον τρόπο χειρισμού των δεδομένων, η εφαρμογή μπορεί να σας ζητήσει να διαβάσετε και να συμφωνήσετε ξανά με την ενημερωμένη πολιτική.';
  }

  @override
  String get privacyGateTitle =>
      'Συμφωνήστε με την πολιτική απορρήτου πριν χρησιμοποιήσετε την εφαρμογή';

  @override
  String get privacyGateSummaryStorage =>
      'Τα προγράμματα, τα σύνολα χρονικών περιόδων και η διαμόρφωση του σχολείου αποθηκεύονται μόνο τοπικά και δεν ανεβάζονται αυτόματα σε διακομιστή προγραμματιστή.';

  @override
  String get privacyGateSummaryImportExport =>
      'Η εισαγωγή, η εξαγωγή και η κοινή χρήση συμβαίνουν μόνο όταν τα ξεκινήσετε ρητά. Η ανάλυση ιστοσελίδας στέλνει μόνο το συμπιεσμένο περιεχόμενο που υποβάλλετε στο τελικό σημείο ανάλυσης που έχετε ρυθμίσει και μπορείτε να αναθεωρήσετε το αναλυμένο χρονοδιάγραμμα πριν αποθηκεύσετε.';

  @override
  String get privacyGateSummaryUpdates =>
      'Εάν μια μεταγενέστερη έκδοση αλλάξει τον τρόπο χειρισμού των δεδομένων, η εφαρμογή μπορεί να σας ζητήσει να αναθεωρήσετε ξανά την ενημερωμένη πολιτική απορρήτου.';

  @override
  String get schoolWebImportEntry => 'Εισαγωγή από την ιστοσελίδα του σχολείου';

  @override
  String get schoolWebImportEntryDesc =>
      'Εισαγωγή της σελίδας του τρέχοντος προγράμματος από την ιστοσελίδα του σχολείου.';

  @override
  String get schoolSitesManageEntry => 'Διαχείριση σχολικών ιστότοπων';

  @override
  String get schoolSitesManageEntryDesc =>
      'Προσθήκη, επεξεργασία και διαγραφή διευθύνσεων URL σύνδεσης σχολείου, με εισαγωγή και εξαγωγή JSON.';

  @override
  String get schoolSitesPageTitle => 'Διαχείριση χώρου σχολείου';

  @override
  String get schoolSitesImportJson => 'Εισαγωγή JSON σχολείου';

  @override
  String get schoolSitesShareJson => 'Μοιραστείτε το σχολείο JSON';

  @override
  String get schoolSitesSaveJson => 'Αποθηκεύστε το σχολείο JSON';

  @override
  String get schoolSitesSaved => 'Σχολικές ιστοσελίδες αποθηκεύτηκαν';

  @override
  String get schoolSitesImported => 'Σχολικές τοποθεσίες που εισάγονται';

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
  String get schoolSitesEmpty => 'Δεν υπάρχει σχολική τοποθεσία ακόμα.';

  @override
  String get schoolSitesNameLabel => 'Όνομα σχολείου';

  @override
  String get schoolSitesLoginUrlLabel => 'URL σύνδεσης';

  @override
  String get schoolSitesAdd => 'Προσθήκη σχολείου';

  @override
  String get schoolSitesEdit => 'Επεξεργασία σχολείου';

  @override
  String get schoolSitesDeleteTitle => 'Διαγραφή σχολείου';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Διαγραφή \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Συμπληρώστε πρώτα το όνομα του σχολείου και τη διεύθυνση σύνδεσης.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Εισαγωγή με επικόλληση περιεχομένου σελίδας προγράμματος';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Επικολλήστε τον πηγαίο κώδικα ή το ακατέργαστο περιεχόμενο σελίδας που περιέχει πληροφορίες χρονοδιαγράμματος με μη αυτόματο τρόπο.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Ανάλυση χρονοδιαγράμματος από το περιεχόμενο της σελίδας';

  @override
  String get schoolHtmlImportUrlLabel => 'URL πηγής (προαιρετικό)';

  @override
  String get schoolHtmlImportTitleLabel => 'Τίτλος σελίδας (προαιρετικό)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Περιεχόμενο σελίδας';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Επικολλήστε τον πηγαίο κώδικα ή το ακατέργαστο περιεχόμενο της σελίδας που περιέχει πληροφορίες για το χρονοδιάγραμμα εδώ.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Οποιοδήποτε περιεχόμενο που περιέχει πληροφορίες χρονοδιάγραμμα μπορεί να αναλυθεί και να εισαχθεί, όχι μόνο HTML.';

  @override
  String get schoolHtmlImportCompress => 'Προετοιμασία περιεχομένου';

  @override
  String get schoolHtmlImportCompressed => 'Το περιεχόμενο προετοιμάστηκε';

  @override
  String get schoolHtmlImportCompressFirst =>
      'Προετοιμάστε πρώτα το περιεχόμενο.';

  @override
  String get schoolHtmlImportSubmit => 'Ανάλυση και εισαγωγή';

  @override
  String get schoolImportContentTruncated =>
      'Αυτή η σελίδα έφτασε το ασφαλές όριο εισαγωγής. Μόνο το τμήμα που καταγράφηκε θα σταλεί για ανάλυση.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Η ανάλυση μπορεί να διαρκέσει λίγο. Παρακαλώ περιμένετε.';

  @override
  String get schoolHtmlImportEmpty => 'Επικολλήστε πρώτα το HTML της σελίδας.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Επιστροφή στην ιστοσελίδα';

  @override
  String get schoolWebImportPageTitle => 'Εισαγωγή ιστοσελίδας σχολείου';

  @override
  String get schoolWebImportPreview => 'Εισαγωγή προεπισκόπησης';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count μαθήματα';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return ' $count περιόδους';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Τίτλος σελίδας';

  @override
  String get schoolWebImportParserUsed => 'Αναλυτής';

  @override
  String get schoolWebImportWarnings => 'Εισαγωγή σημειώσεων';

  @override
  String get schoolWebImportOpenPageHint =>
      'Συνδεθείτε στην ιστοσελίδα του σχολείου μέσα στην εφαρμογή και, στη συνέχεια, πλοηγηθείτε στη σελίδα του προγράμματος με μη αυτόματο τρόπο.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Αυτή η πλατφόρμα δεν υποστηρίζει ακόμα ενσωματωμένη σύνδεση στο διαδίκτυο. Χρησιμοποιήστε μια πλατφόρμα με υποστήριξη WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Επιλέξτε το σχολείο';

  @override
  String get schoolWebImportNoSchools =>
      'Δεν υπάρχει διαθέσιμη διαμόρφωση σχολείου. Ελέγξτε πρώτα το school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Αποτυχία φόρτωσης ρυθμίσεων σχολείου. Ελέγξτε τη μορφή αρχείου JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Εισαγωγή τρέχουσας σελίδας';

  @override
  String get schoolWebImportGoBack => 'Προηγούμενη σελίδα';

  @override
  String get schoolWebImportLoadingPage => 'Φόρτωση σελίδας…';

  @override
  String get schoolWebImportParsing => 'Ανάλυση τρέχουσας σελίδας...';

  @override
  String get schoolWebImportLoadFailed =>
      'Αποτυχία φόρτωσης σελίδας. Ανανεώστε ή δοκιμάστε ξανά αργότερα.';

  @override
  String get schoolWebImportLoadTimedOut =>
      'Η φόρτωση σελίδας έχει λήξει το χρόνο. Ανανεώστε και δοκιμάστε ξανά.';

  @override
  String get schoolWebImportUnknownOrigin => 'Άγνωστος ιστότοπος';

  @override
  String get schoolWebImportCrossOriginTitle => 'Συνέχεια σε άλλον ιστότοπο;';

  @override
  String schoolWebImportCrossOriginMessage(Object origin) {
    return 'Η σύνδεση στο σχολικό σύστημα ενδέχεται να χρειαστεί να ανοίξει άλλον ιστότοπο. Συνεχίστε μόνο αν εμπιστεύεστε αυτόν τον προορισμό για την τρέχουσα περίοδο εισαγωγής:\n\n$origin';
  }

  @override
  String get schoolWebImportEmptyPage =>
      'Το τρέχον περιεχόμενο της σελίδας είναι άδειο και δεν μπορεί ακόμα να εισαχθεί.';

  @override
  String get schoolWebImportSuccess => 'Εισαγωγή προγράμματος Web';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSettingsLocationHint =>
      'Configure it in Settings > Data & security > AI API configuration.';

  @override
  String get schoolImportParserSourceTitle => 'Πηγή αναλύτη';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Προσαρμοσμένη OpenAI-συμβατή';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Προσαρμοσμένος αναλυτής συμβατός με OpenAI';

  @override
  String get schoolImportParserCustomPromptTitle =>
      'Προσαρμοσμένη προειδοποίηση';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Επεξεργαστείτε το ενσωματωμένο parser prompt εδώ. Οι αλλαγές επηρεάζουν μόνο τον προσαρμοσμένο αναλυτή συμβατό με OpenAI.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Το ενσωματωμένο prompt φορτώνεται εδώ από προεπιλογή. Καθαρίστε το για να επιστρέψετε στην ενσωματωμένη έκδοση.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Επαναφορά προεπιλεγμένης οδηγίας';

  @override
  String get schoolImportParserBaseUrl => 'URL βάσης';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Το Base URL πρέπει να είναι διεύθυνση HTTP ή HTTPS με κεντρικό υπολογιστή.';

  @override
  String get schoolImportParserApiKey => 'API κλειδί';

  @override
  String get schoolImportParserModel => 'μοντέλο';

  @override
  String get schoolImportParserFetchModels => 'Λίστα μοντέλων';

  @override
  String get schoolImportParserFetchingModels => 'Φέρνει μοντέλα. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Κανένα μοντέλο δεν επιστρέφηκε από το τελικό σημείο.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Δεν ήταν δυνατή η ανάκτηση των μοντέλων. Ελέγξτε το τελικό σημείο και δοκιμάστε ξανά.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Λήφθηκε $count μοντέλα';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Χρήση μη κρυπτογραφημένου τελικού σημείου HTTP;';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'Το κλειδί API και το περιεχόμενο του ωρολογίου προγράμματος ενδέχεται να διαβαστούν ή να τροποποιηθούν κατά τη μεταφορά. Συνεχίστε μόνο αν εμπιστεύεστε αυτήν τη συσκευή, το δίκτυο και το τελικό σημείο. Η έγκριση ισχύει μέχρι να κλείσετε το Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Η προσαρμοσμένη διαμόρφωση του αναλυτή είναι ελλιπής. Συμπληρώστε πρώτα την URL βάσης, το κλειδί API και το μοντέλο.';

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
    return 'Αναλυτής: Προσαρμοσμένη ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Δείτε πλήρη πολιτική απορρήτου';

  @override
  String get privacyAgreeAndContinue => 'Συμφωνήστε και συνεχίστε';

  @override
  String get privacyDecline => 'Απέρριψη';

  @override
  String get privacyDeclineWebHint =>
      'Αυτό το περιβάλλον περιήγησης δεν επιτρέπει στην εφαρμογή να κλείσει τη σελίδα για εσάς. Αν δεν συμφωνείτε, παρακαλούμε κλείστε αυτή την καρτέλα ή το παράθυρο μόνοι σας.';

  @override
  String get defaultPeriodTimeSetName => 'Προεπιλεγμένες περιόδους';

  @override
  String get periodTimeSetFallbackName => 'Χρόνοι περιόδου';

  @override
  String get untitledTimetableName => 'Χωρίς τίτλο χρονοδιάγραμμα';

  @override
  String get newTimetableName => 'Νέο χρονοδιάγραμμα';

  @override
  String get newPeriodTimeSetName => 'Νέα χρονική περίοδος';

  @override
  String get emptyTimetableName => 'Κενό χρονοδιάγραμμα';

  @override
  String importedPeriodTimeSetName(Object name) {
    return ' $name περιόδους';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Ο τύπος αρχείου εισαγωγής δεν ταιριάζει.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Αυτή η έκδοση αρχείου εισαγωγής δεν υποστηρίζεται ακόμα.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Δεν βρέθηκαν χρονικές περιόδους στο αρχείο εισαγωγής.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Επιλέξτε τουλάχιστον ένα χρονοδιάγραμμα.';

  @override
  String get noExportableTimetableMessage =>
      'Δεν υπάρχει διαθέσιμο χρονοδιάγραμμα για την εξαγωγή.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Η αντικατάσταση του τρέχοντος προγράμματος υποστηρίζει μόνο την επιλογή ενός προγράμματος.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Δεν υπάρχει τρέχον χρονοδιάγραμμα για αντικατάσταση.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Αυτό το χρονοδιάγραμμα περιόδου εξακολουθεί να χρησιμοποιείται από το χρονοδιάγραμμα $count. Αναπροσδιορίστε τους πριν διαγράψετε.';
  }

  @override
  String get weekdayMonday => 'Δευτέρα';

  @override
  String get weekdayTuesday => 'Τρίτη';

  @override
  String get weekdayWednesday => 'Τετάρτη';

  @override
  String get weekdayThursday => 'Πέμπτη';

  @override
  String get weekdayFriday => 'Παρασκευή';

  @override
  String get weekdaySaturday => 'Σάββατο';

  @override
  String get weekdaySunday => 'Κυριακή';

  @override
  String get weekdayShortMonday => 'Δευτέρα';

  @override
  String get weekdayShortTuesday => 'Τρίτη';

  @override
  String get weekdayShortWednesday => 'Τετάρτη';

  @override
  String get weekdayShortThursday => 'Πέμπτη';

  @override
  String get weekdayShortFriday => 'Παρασκευή';

  @override
  String get weekdayShortSaturday => 'Σάββατο';

  @override
  String get weekdayShortSunday => 'Ήλιος';

  @override
  String get monthJanuary => 'Ιαν';

  @override
  String get monthFebruary => 'Φεβρουάριος';

  @override
  String get monthMarch => 'Μαρ';

  @override
  String get monthApril => 'Απρίλιος';

  @override
  String get monthMay => 'Μάιος';

  @override
  String get monthJune => 'Ιούνιος';

  @override
  String get monthJuly => 'Ιούλιος';

  @override
  String get monthAugust => 'Αύγουστος';

  @override
  String get monthSeptember => 'Σεπ';

  @override
  String get monthOctober => 'Οκτ';

  @override
  String get monthNovember => 'Νοεμβρίου';

  @override
  String get monthDecember => 'Δεκ';

  @override
  String get semesterWeeksWholeTerm => 'Όλο το εξάμηνο';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Εβδομάδες $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Εβδομάδες $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Επιλέξτε λειτουργία εκκίνησης';

  @override
  String get firstLaunchSubtitle =>
      'Επιλέξτε τον χώρο εργασίας που χρησιμοποιείτε περισσότερο. Μπορείτε να αλλάξετε λειτουργία αργότερα.';

  @override
  String get firstLaunchStudentDesc =>
      'Διαχειριστείτε ωρολόγια προγράμματα, μαθήματα, εβδομάδες, ώρες περιόδων και εισαγωγές.';

  @override
  String get firstLaunchGeneralDesc =>
      'Διαχειριστείτε κατηγορίες, συμβάντα, υπενθυμίσεις και δεδομένα JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Έναρξη με ωρολόγιο πρόγραμμα';

  @override
  String get firstLaunchStartGeneral => 'Έναρξη με πρόγραμμα';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Επιλέγοντας έναν αρχικό χώρο εργασίας, επιβεβαιώνετε ότι έχετε διαβάσει και αποδέχεστε την ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Πολιτική απορρήτου';

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
  String get today => 'Σήμερα';

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
      'Προβολές, γραμμή εργαλείων, μορφή ημερομηνίας και γρήγορη προσθήκη';

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
  String get viewWeek => 'Εβδομάδα';

  @override
  String get viewDay => 'Ημέρα';

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
  String get schoolWebImportSignInConsentTitle =>
      'Άνοιγμα σύνδεσης στο σχολικό σύστημα;';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Η σύνδεση στο σχολικό σύστημα μπορεί να υποβάλει διαπιστευτήρια μέσω φορμών ή ανακατευθύνσεων διακομιστή στο σχολείο και στους παρόχους σύνδεσής του. Το Android δεν μπορεί να διακόπτει κάθε τέτοια μεταφορά για ξεχωριστή επιβεβαίωση προορισμού. Συνεχίστε μόνο αν τους εμπιστεύεστε για αυτήν την περίοδο εισαγωγής:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Άνοιγμα μη ασφαλούς σύνδεσης σχολείου;';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Αυτή η σύνδεση σχολείου χρησιμοποιεί HTTP. Όποιος μπορεί να παρακολουθήσει ή να αλλοιώσει αυτή τη σύνδεση μπορεί να διαβάσει ή να αλλάξει τα διαπιστευτήρια και το περιεχόμενο της σελίδας σας. Συνεχίστε μόνο αν αποδέχεστε αυτόν τον κίνδυνο για:\n\n$origin';
  }

  @override
  String get developerModeTitle => 'Λειτουργία προγραμματιστή';

  @override
  String get developerModeDescription =>
      'Εργαλεία για την προσθήκη πλήρων δειγματικών δεδομένων για έλεγχο εμφάνισης και αλληλεπίδρασης.';

  @override
  String get developerSampleLanguage => 'Γλώσσα δειγματικών δεδομένων';

  @override
  String get developerSampleChinese => 'Κινεζικά';

  @override
  String get developerSampleEnglish => 'Αγγλικά';

  @override
  String get developerSampleDataDescription =>
      'Προσθέτει ένα ωρολόγιο πρόγραμμα και ένα σύνολο κατηγοριών και συμβάντων χωρίς αντικατάσταση υπαρχόντων δεδομένων.';

  @override
  String get developerAddSampleData => 'Προσθήκη δειγματικών δεδομένων';

  @override
  String get developerSampleDataAdded =>
      'Προστέθηκαν δείγματα ωρολογίου προγράμματος και συμβάντων.';

  @override
  String get developerModeLongPressHint =>
      'Πατήστε παρατεταμένα για 3 δευτερόλεπτα για να ανοίξετε τη λειτουργία προγραμματιστή';

  @override
  String get collapseWorkspaceNavigation => 'Σύμπτυξη πλοήγησης χώρου εργασίας';

  @override
  String get expandWorkspaceNavigation => 'Ανάπτυξη πλοήγησης χώρου εργασίας';
}
