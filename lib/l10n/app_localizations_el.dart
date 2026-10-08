// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class AppLocalizationsEl extends AppLocalizations {
  AppLocalizationsEl([String locale = 'el']) : super(locale);

  @override
  String get appTitle => 'Sked';

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
  String get schoolImportResultEditorTitle =>
      'Επεξεργασία αποτελέσματος ανάλυσης';

  @override
  String get schoolImportParsePageTitle => 'Ανάλυση προγράμματος';

  @override
  String get schoolImportParsePageParsing => 'Ανάλυση…';

  @override
  String get schoolImportParsePageFailed => 'Η ανάλυση απέτυχε';

  @override
  String get schoolImportParsePageComplete => 'Η ανάλυση ολοκληρώθηκε';

  @override
  String get schoolImportParsePageContinue => 'Συνέχεια';

  @override
  String get schoolImportParsePageRawContent => 'Ακατέργαστη απόκριση';

  @override
  String get schoolImportParsePageExpandRaw =>
      'Ανάπτυξη ακατέργαστης απόκρισης';

  @override
  String get schoolImportParsePageCollapseRaw =>
      'Σύμπτυξη ακατέργαστης απόκρισης';

  @override
  String get schoolImportExpandWarnings => 'Ανάπτυξη προειδοποιήσεων εισαγωγής';

  @override
  String get schoolImportCollapseWarnings =>
      'Σύμπτυξη προειδοποιήσεων εισαγωγής';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Ορισμένα μαθήματα συνεχίζονται έως την εβδομάδα $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Αντικατάσταση τρέχοντος προγράμματος;';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Το εισαγόμενο πρόγραμμα θα αντικαταστήσει το τρέχον.';

  @override
  String get createTimetable => 'Νέο χρονοδιάγραμμα';

  @override
  String get jumpToWeek => 'Μετάβαση στην εβδομάδα';

  @override
  String get timetable => 'Χρονολόγιο';

  @override
  String get themeWorkspaceSchedule => 'Πρόγραμμα';

  @override
  String get timetableName => 'Όνομα προγράμματος';

  @override
  String get timetableNameRequired => 'Εισαγάγετε όνομα προγράμματος';

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
  String get settingsSectionTimetable => 'Πρόγραμμα μαθημάτων';

  @override
  String get settingsSectionGeneralSchedule => 'Γενικό πρόγραμμα';

  @override
  String get settingsSectionAppearance => 'Εμφάνιση';

  @override
  String get settingsSectionApp => 'Εφαρμογή';

  @override
  String get settingsSectionWorkspace => 'Χώρος εργασίας';

  @override
  String get settingsSectionAppearanceLanguage => 'Εμφάνιση και γλώσσα';

  @override
  String get settingsSectionDataSecurity => 'Δεδομένα και ασφάλεια';

  @override
  String get settingsSectionAbout => 'Σχετικά με το Sked';

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
      'Οριζόντια διάταξη και χειρονομίες';

  @override
  String get fitDaySelectorToWidth => 'Προσαρμογή επιλογής ημέρας στην οθόνη';

  @override
  String get fitDaySelectorToWidthHint =>
      'Εμφανίζει και τις επτά ημέρες στην οθόνη όταν είναι δυνατό. Απενεργοποιήστε το για σταθερό πλάτος και κύλιση.';

  @override
  String get fitWeekColumnsToWidth => 'Προσαρμογή στηλών εβδομάδας στην οθόνη';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Εμφανίζει και τις επτά στήλες του προγράμματος στην οθόνη όταν είναι δυνατό. Απενεργοποιήστε το για σταθερό πλάτος και κύλιση.';

  @override
  String get enableWeekSwipeNavigation => 'Αλλαγή εβδομάδας με σάρωση';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Σαρώστε αριστερά ή δεξιά για άλλη εβδομάδα. Με σταθερό πλάτος, κυλήστε πρώτα μέχρι την άκρη.';

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
  String get outlineWidthUnit => 'px';

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
  String get microsoftStoreUpdates =>
      'Οι ενημερώσεις διαχειρίζονται από το Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Λήψη προκαταρκτικών ενημερώσεων';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Συμπερίληψη εκδόσεων Alpha, Beta και RC, που ενδέχεται να είναι ασταθείς. Όταν είναι ανενεργό, προσφέρονται μόνο σταθερές εκδόσεις.';

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
  String get googlePlay => 'Google Play';

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
      'Δεν ήταν δυνατή η λήψη της τελευταίας έκδοσης από το GitHub. Μπορείτε να ανοίξετε το GitHub Releases παρακάτω.';

  @override
  String get githubRepository => 'Αποθήκευση GitHub';

  @override
  String get googlePlayStoreDesc => 'Προβολή του Sked στο Google Play';

  @override
  String get openGooglePlayFailed =>
      'Δεν ήταν δυνατό το άνοιγμα του Google Play';

  @override
  String get starSkedOnGithub => 'Δώστε ένα αστέρι στο Sked στο GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Ανοίξτε το αποθετήριο του έργου και δώστε ένα αστέρι στο Sked';

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
  String get periodTimesUnsavedExitTitle => 'Οι αλλαγές δεν αποθηκεύτηκαν';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Οι τελευταίες αλλαγές στις ώρες μαθημάτων δεν αποθηκεύτηκαν. Μπορείτε να προσπαθήσετε ξανά, να συνεχίσετε την επεξεργασία ή να τις απορρίψετε.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Ορισμένες ώρες μαθημάτων δεν είναι έγκυρες. Διορθώστε τις πριν από την αποθήκευση ή απορρίψτε τις αλλαγές και εξέλθετε.';

  @override
  String get discardChangesAndExit => 'Απόρριψη και έξοδος';

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
      'Στις εγγενείς εκδόσεις, το Sked αποθηκεύει τα προγράμματα μαθημάτων, τα γενικά προγράμματα, τις σχετικές ρυθμίσεις και την επεξεργάσιμη διαμόρφωση σχολικών ιστοτόπων στον κατάλογο υποστήριξης εφαρμογών του λειτουργικού συστήματος. Η έκδοση ιστού χρησιμοποιεί τον χώρο αποθήκευσης του προγράμματος περιήγησης. Αρχεία που παλαιότερες εκδόσεις αποθήκευσαν στον φάκελο Έγγραφα παραμένουν εκεί, αλλά δεν διαβάζονται ούτε μεταφέρονται αυτόματα. Για να διατηρήσετε αυτά τα δεδομένα, εξαγάγετε πλήρες αντίγραφο ασφαλείας από την παλιά έκδοση πριν από την αναβάθμιση και επαναφέρετέ το μετά. Οι ρυθμίσεις AI API αποθηκεύονται τοπικά. Το προσαρμοσμένο κλειδί API αποθηκεύεται μέσω του ασφαλούς χώρου αποθήκευσης της πλατφόρμας, όταν είναι διαθέσιμος. Τα πλήρη αντίγραφα ασφαλείας δεν περιλαμβάνουν αυτό το κλειδί. Η εφαρμογή δεν μεταφορτώνει αυτόματα τα τοπικά δεδομένα σε διακομιστή που ελέγχεται από τον προγραμματιστή.';

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
  String get schoolSitesImportPreviewTitle =>
      'Έλεγχος εισαγωγής σχολικών ιστοτόπων';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return 'Έγκυροι ιστότοποι: $validCount, μη έγκυρες εγγραφές: $invalidCount.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Το αρχείο περιέχει κενή λίστα σχολικών ιστοτόπων.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Η εγγραφή $position δεν είναι έγκυρη και θα παραλειφθεί.';
  }

  @override
  String get schoolSitesImportMerge => 'Συγχώνευση';

  @override
  String get schoolSitesImportReplace => 'Αντικατάσταση';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Αντικατάσταση τρεχόντων σχολικών ιστοτόπων;';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Θα αφαιρεθούν οι $currentCount τρέχοντες ιστότοποι και θα αποθηκευτούν $importedCount εισαγόμενοι ιστότοποι. Η ενέργεια δεν αναιρείται.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Τα δεδομένα σχολικών ιστοτόπων χρειάζονται ανάκτηση';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Το Sked δεν μπόρεσε να διαβάσει το αρχείο σχολικών ιστοτόπων ή το αντίγραφο ασφαλείας του. Δημιουργήθηκαν προστατευμένα αντίγραφα πριν αποκλειστεί η εγγραφή.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Ο χώρος αποθήκευσης σχολικών ιστοτόπων δεν είναι διαθέσιμος';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Το Sked δεν έχει τώρα πρόσβαση στον χώρο αποθήκευσης σχολικών ιστοτόπων. Ελέγξτε την πρόσβαση ή τη διαθεσιμότητα της συσκευής και δοκιμάστε ξανά. Τα τρέχοντα δεδομένα δεν θα αντικατασταθούν.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Παρακάτω εμφανίζονται τα αρχεία ανάκτησης ή οι επηρεαζόμενες θέσεις αποθήκευσης. Μην αλλάξετε τα αρχεία μέχρι να ανακτηθεί η λίστα ιστοτόπων.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Έναρξη χωρίς σχολικούς ιστοτόπους';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Έναρξη με κενή λίστα σχολικών ιστοτόπων;';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Τα προστατευμένα αντίγραφα θα διατηρηθούν, αλλά το Sked θα δημιουργήσει νέο κενό αρχείο σχολικών ιστοτόπων. Συνεχίστε μόνο αν δεν θέλετε να δοκιμάσετε πρώτα ξανά την ανάκτηση.';

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
  String get schoolWebImportParserDetails => 'Λεπτομέρειες ανάλυσης';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Ανάπτυξη λεπτομερειών ανάλυσης';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Σύμπτυξη λεπτομερειών ανάλυσης';

  @override
  String get schoolWebImportOpenPageHint =>
      'Συνδεθείτε στην ιστοσελίδα του σχολείου μέσα στην εφαρμογή και, στη συνέχεια, πλοηγηθείτε στη σελίδα του προγράμματος με μη αυτόματο τρόπο.';

  @override
  String get schoolWebImportConfigMissing =>
      'Η διαμόρφωση του προσαρμοσμένου αναλυτή είναι ελλιπής. Συμπληρώστε πρώτα τη βασική διεύθυνση URL, το κλειδί API και το μοντέλο.';

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
  String get schoolWebImportLoadingPage => 'Φόρτωση σελίδας…';

  @override
  String get schoolWebImportParsing => 'Ανάλυση τρέχουσας σελίδας...';

  @override
  String get schoolWebImportLoadFailed =>
      'Αποτυχία φόρτωσης σελίδας. Ανανεώστε ή δοκιμάστε ξανά αργότερα.';

  @override
  String get schoolWebImportUnknownOrigin => 'Άγνωστος ιστότοπος';

  @override
  String get schoolWebImportExitTitle => 'Έξοδος από το πρόγραμμα περιήγησης;';

  @override
  String get schoolWebImportExitMessage =>
      'Η σελίδα θα κλείσει. Ό,τι δεν έχετε εισαγάγει ακόμη θα χαθεί.';

  @override
  String get schoolWebImportExitConfirm => 'Έξοδος';

  @override
  String get schoolWebImportEmptyPage =>
      'Το τρέχον περιεχόμενο της σελίδας είναι άδειο και δεν μπορεί ακόμα να εισαχθεί.';

  @override
  String get schoolWebImportSuccess => 'Εισαγωγή προγράμματος Web';

  @override
  String get schoolImportParserSettingsTitle => 'API εισαγωγής ωρολογίου';

  @override
  String get schoolImportParserSettingsDesc =>
      'Ρυθμίστε το συμβατό με OpenAI API για εισαγωγή ωρολογίων, όχι για βοηθό συνομιλίας.';

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
      'Το προσαρμοσμένο κλειδί API αποθηκεύεται μέσω του ασφαλούς χώρου αποθήκευσης της πλατφόρμας, όταν είναι διαθέσιμος. Χρησιμοποιείτε διαπιστευτήρια αναλυτή και διευθύνσεις HTTP μόνο σε συσκευές, προγράμματα περιήγησης και δίκτυα που εμπιστεύεστε.';

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
  String get clearAppData => 'Εκκαθάριση δεδομένων';

  @override
  String get clearAppDataDesc =>
      'Οριστική διαγραφή όλων των τοπικών δεδομένων του Sked και έξοδος';

  @override
  String get clearAppDataConfirmTitle =>
      'Εκκαθάριση όλων των δεδομένων του Sked;';

  @override
  String get clearAppDataConfirmMessage =>
      'Διαγράφει οριστικά προγράμματα μαθημάτων, γενικά προγράμματα, ρυθμίσεις, σχολικούς ιστοτόπους, τοπικά αντίγραφα ασφαλείας, αντίγραφα ανάκτησης και το κλειδί AI API και έπειτα κλείνει το Sked. Αρχεία που εξαγάγατε αλλού δεν διαγράφονται. Η ενέργεια δεν αναιρείται.';

  @override
  String get clearAppDataAction => 'Εκκαθάριση δεδομένων και έξοδος';

  @override
  String get clearAppDataFailed =>
      'Δεν ήταν δυνατή η εκκαθάριση όλων των τοπικών δεδομένων. Το Sked θα μείνει ανοιχτό για να δοκιμάσετε ξανά.';

  @override
  String get clearAppDataExitFailed =>
      'Τα τοπικά δεδομένα διαγράφηκαν, αλλά το Sked δεν μπόρεσε να κλείσει. Κλείστε το χειροκίνητα πριν το χρησιμοποιήσετε ξανά.';

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
  String get generalSchedule => 'Γενικό πρόγραμμα';

  @override
  String get studentTimetable => 'Πρόγραμμα μαθημάτων';

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
  String get switchMode => 'Αλλαγή λειτουργίας';

  @override
  String get generalScheduleComingSoon => 'Το γενικό πρόγραμμα έρχεται σύντομα';

  @override
  String get switchToStudentTimetable => 'Μετάβαση στο πρόγραμμα μαθημάτων';

  @override
  String get mySchedule => 'Το πρόγραμμά μου';

  @override
  String get today => 'Σήμερα';

  @override
  String get addEvent => 'Προσθήκη συμβάντος';

  @override
  String get editEvent => 'Επεξεργασία συμβάντος';

  @override
  String get eventTitle => 'Τίτλος';

  @override
  String get eventTitleRequired => 'Απαιτείται τίτλος';

  @override
  String get eventStartTime => 'Ώρα έναρξης';

  @override
  String get eventEndTime => 'Ώρα λήξης';

  @override
  String get eventDate => 'Ημερομηνία';

  @override
  String get eventTime => 'Ώρα';

  @override
  String get eventNotes => 'Σημειώσεις';

  @override
  String get eventColor => 'Χρώμα';

  @override
  String get eventRecurrence => 'Επανάληψη';

  @override
  String get recurrenceNone => 'Χωρίς επανάληψη';

  @override
  String get recurrenceWeekly => 'Κάθε εβδομάδα';

  @override
  String get recurrenceEndDate => 'Ημερομηνία λήξης';

  @override
  String get recurrenceNoEndDate => 'Χωρίς ημερομηνία λήξης';

  @override
  String get recurrenceSetEndDate => 'Ορισμός';

  @override
  String get recurrenceChangeEndDate => 'Αλλαγή';

  @override
  String get repeatsWeekly => 'Επαναλαμβάνεται κάθε εβδομάδα';

  @override
  String recurrenceUntil(Object date) {
    return 'Έως $date';
  }

  @override
  String get switchToGeneralSchedule => 'Μετάβαση στο γενικό πρόγραμμα';

  @override
  String get generalDisplaySettings => 'Ρυθμίσεις εμφάνισης προγράμματος';

  @override
  String get generalDisplaySettingsDesc =>
      'Προβολές, γραμμή εργαλείων, μορφή ημερομηνίας και γρήγορη προσθήκη';

  @override
  String get closePopupOnOutsideTap => 'Κλείσιμο αναδυόμενου με πάτημα εκτός';

  @override
  String get showGridLines => 'Εμφάνιση γραμμών πλέγματος';

  @override
  String get generalScheduleImportExport => 'Εισαγωγή και εξαγωγή κατηγοριών';

  @override
  String get generalScheduleImportExportDesc =>
      'Εισαγωγή ή κοινοποίηση κατηγοριών προγράμματος';

  @override
  String get importGeneralSchedules => 'Εισαγωγή κατηγοριών';

  @override
  String get importGeneralSchedulesDesc =>
      'Ανάγνωση κατηγοριών από αρχείο JSON';

  @override
  String get shareGeneralSchedules => 'Κοινοποίηση κατηγοριών';

  @override
  String get shareGeneralSchedulesDesc =>
      'Κοινοποίηση κατηγοριών ως αρχείο JSON';

  @override
  String get saveGeneralSchedules => 'Αποθήκευση κατηγοριών';

  @override
  String get saveGeneralSchedulesDesc => 'Αποθήκευση κατηγοριών ως αρχείο JSON';

  @override
  String get selectSchedulesToExport => 'Επιλογή κατηγοριών για εξαγωγή';

  @override
  String get selectSchedulesToImport => 'Επιλογή κατηγοριών για εισαγωγή';

  @override
  String generalScheduleEventCount(int count) {
    return 'Συμβάντα: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Εισαγόμενες κατηγορίες: $count';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Προσθήκη ως νέα κατηγορία ή αντικατάσταση υπάρχουσας;';

  @override
  String get addAsNewSchedule => 'Προσθήκη ως νέα κατηγορία';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Επιλέξτε τουλάχιστον μία κατηγορία.';

  @override
  String get noExportableScheduleMessage =>
      'Δεν υπάρχει διαθέσιμη κατηγορία για εξαγωγή.';

  @override
  String get noSchedulesInImportMessage =>
      'Το αρχείο εισαγωγής δεν περιέχει κατηγορίες.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Επιλέξτε ακριβώς μία εισαγόμενη κατηγορία για αντικατάσταση.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Η επιλεγμένη κατηγορία προς αντικατάσταση δεν είναι διαθέσιμη.';

  @override
  String get calendars => 'Κατηγορίες';

  @override
  String get calendar => 'Κατηγορία';

  @override
  String get viewWeek => 'Εβδομάδα';

  @override
  String get viewDay => 'Ημέρα';

  @override
  String get viewList => 'Λίστα';

  @override
  String get viewMonth => 'Μήνας';

  @override
  String visibleCategoryCount(int count) {
    return 'Κατηγορίες: $count';
  }

  @override
  String get noVisibleCategories => 'Δεν υπάρχουν ορατές κατηγορίες';

  @override
  String get selectCategoryToReplace => 'Επιλογή κατηγορίας προς αντικατάσταση';

  @override
  String get replaceCategory => 'Αντικατάσταση κατηγορίας';

  @override
  String get deleteEventTitle => 'Διαγραφή συμβάντος';

  @override
  String get deleteEventConfirmation => 'Αυτό το συμβάν θα διαγραφεί οριστικά.';

  @override
  String get deleteRecurringEventTitle =>
      'Διαγραφή επαναλαμβανόμενου συμβάντος';

  @override
  String get eventDuplicated => 'Το συμβάν αντιγράφηκε';

  @override
  String get searchEvents => 'Αναζήτηση συμβάντων';

  @override
  String get clearSearch => 'Εκκαθάριση αναζήτησης';

  @override
  String get filterByColor => 'Φιλτράρισμα ανά χρώμα';

  @override
  String get allColors => 'Όλα τα χρώματα';

  @override
  String upcomingEventsCount(int count) {
    return 'Επερχόμενα: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Με περασμένη ώρα λήξης: $count';
  }

  @override
  String get allDay => 'Ολοήμερο';

  @override
  String get collapseAllDayTimeline => 'Σύμπτυξη ολοήμερων συμβάντων';

  @override
  String get expandAllDayTimeline => 'Ανάπτυξη ολοήμερων συμβάντων';

  @override
  String allDayEventsCount(int count) {
    return 'Ολοήμερα συμβάντα: $count';
  }

  @override
  String moreEvents(int count) {
    return '+$count ακόμη';
  }

  @override
  String get noMatchingEvents => 'Δεν υπάρχουν αντίστοιχα συμβάντα';

  @override
  String get noUpcomingEvents => 'Δεν υπάρχουν επερχόμενα συμβάντα';

  @override
  String get addCalendar => 'Προσθήκη κατηγορίας';

  @override
  String get newCalendar => 'Νέα κατηγορία';

  @override
  String get hideCalendar => 'Απόκρυψη κατηγορίας';

  @override
  String get showCalendar => 'Εμφάνιση κατηγορίας';

  @override
  String get rename => 'Μετονομασία';

  @override
  String get renameCalendar => 'Μετονομασία κατηγορίας';

  @override
  String get name => 'Όνομα';

  @override
  String get deleteCalendar => 'Διαγραφή κατηγορίας';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Διαγραφή του «$name»;';
  }

  @override
  String get deleteThisOccurrence => 'Διαγραφή μόνο αυτής της εμφάνισης';

  @override
  String get deleteFutureOccurrences => 'Διαγραφή αυτής και των επόμενων';

  @override
  String get deleteAllOccurrences => 'Διαγραφή ολόκληρης της σειράς';

  @override
  String get duplicateEvent => 'Δημιουργία αντιγράφου';

  @override
  String get repeatsDaily => 'Επαναλαμβάνεται κάθε ημέρα';

  @override
  String get repeatsMonthly => 'Επαναλαμβάνεται κάθε μήνα';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Διάστημα επανάληψης: $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count φορές';
  }

  @override
  String get recurrenceDaily => 'Καθημερινά';

  @override
  String get recurrenceMonthly => 'Κάθε μήνα';

  @override
  String get recurrenceCustom => 'Προσαρμοσμένο';

  @override
  String get recurrenceEvery => 'Κάθε';

  @override
  String get recurrenceUnit => 'Μονάδα';

  @override
  String get recurrenceDays => 'ημέρες';

  @override
  String get recurrenceWeeks => 'εβδομάδες';

  @override
  String get recurrenceMonths => 'μήνες';

  @override
  String get recurrenceRepeatCount => 'Αριθμός επαναλήψεων';

  @override
  String get recurrenceNoLimit => 'Χωρίς όριο';

  @override
  String get recurrencePositiveNumber => 'Εισαγάγετε θετικό αριθμό';

  @override
  String get clearEndDate => 'Εκκαθάριση ημερομηνίας λήξης';

  @override
  String get pickDate => 'Επιλογή ημερομηνίας';

  @override
  String get pickTime => 'Επιλογή ώρας';

  @override
  String get reminder => 'Υπενθύμιση στην εφαρμογή';

  @override
  String get reminderAtStart => 'Στην έναρξη';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes λεπτά πριν';
  }

  @override
  String get reminderHourBefore => '1 ώρα πριν';

  @override
  String get reminderDayBefore => '1 ημέρα πριν';

  @override
  String get markReminderHandled => 'Σήμανση ως διεκπεραιωμένη';

  @override
  String get restoreReminder => 'Επαναφορά υπενθύμισης στην εφαρμογή';

  @override
  String get reminderHandled =>
      'Η υπενθύμιση στην εφαρμογή επισημάνθηκε ως διεκπεραιωμένη';

  @override
  String get reminderRestored => 'Η υπενθύμιση στην εφαρμογή επαναφέρθηκε';

  @override
  String get reminderUpcoming => 'Επερχόμενη';

  @override
  String get reminderOverdue => 'Πέρασε η ώρα λήξης';

  @override
  String get generalFitWeekColumnsToWidth => 'Προσαρμογή εβδομάδας στην οθόνη';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Εμφάνιση ολόκληρης της εβδομάδας σε συμπαγείς διατάξεις. Απενεργοποιήστε για οριζόντια κύλιση. Τα προσαρμοσμένα εύρη άνω των 7 ημερών εξακολουθούν να κυλίονται.';

  @override
  String get showWeekends => 'Εμφάνιση Σαββατοκύριακου';

  @override
  String get startHour => 'Ώρα έναρξης προβολής';

  @override
  String get endHour => 'Ώρα λήξης προβολής';

  @override
  String get timeGridDensity => 'Διάστημα πλέγματος ώρας';

  @override
  String get timeGridHourHeight => 'Ύψος γραμμής ανά ώρα';

  @override
  String get timeGridHourHeightHint =>
      'Προσαρμόζει την κατακόρυφη κλίμακα της ημερήσιας και εβδομαδιαίας προβολής χωρίς να αλλάζει το διάστημα πλέγματος 15, 30 ή 60 λεπτών.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Εισαγωγή αρχείου JSON';

  @override
  String get pasteJson => 'Επικόλληση JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Εισαγωγή κατηγοριών από αντιγραμμένο JSON';

  @override
  String get importIcsFile => 'Εισαγωγή αρχείου ICS';

  @override
  String get importIcsFileDesc =>
      'Ανάγνωση συμβάντων από αρχείο ημερολογίου .ics';

  @override
  String get pasteIcs => 'Επικόλληση ICS';

  @override
  String get pasteIcsDesc =>
      'Εισαγωγή συμβάντων από αντιγραμμένο κείμενο ημερολογίου';

  @override
  String get copyJson => 'Αντιγραφή JSON';

  @override
  String get copyJsonDesc => 'Αντιγραφή επιλεγμένων κατηγοριών ως κείμενο JSON';

  @override
  String get shareIcs => 'Κοινοποίηση ICS';

  @override
  String get shareIcsDesc => 'Κοινοποίηση επιλεγμένων ημερολογίων ως .ics';

  @override
  String get saveIcs => 'Αποθήκευση ICS';

  @override
  String get saveIcsDesc => 'Αποθήκευση επιλεγμένων ημερολογίων ως .ics';

  @override
  String get copyIcs => 'Αντιγραφή ICS';

  @override
  String get copyIcsDesc => 'Αντιγραφή επιλεγμένων ημερολογίων ως κείμενο ICS';

  @override
  String get importIcs => 'Εισαγωγή ICS';

  @override
  String get icsContent => 'Περιεχόμενο ICS';

  @override
  String get pasteIcsContentHint =>
      'Επικολλήστε εδώ περιεχόμενο που αρχίζει με BEGIN:VCALENDAR';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Βρέθηκαν $count συμβάντα. Προσθήκη σε νέα κατηγορία ή αντικατάσταση υπάρχουσας;';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Εισήχθησαν $count κατηγορίες με $warningCount προειδοποιήσεις';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Παραλείφθηκε συμβάν χωρίς ώρα έναρξης.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Παραλείφθηκε συμβάν με μη υποστηριζόμενη ώρα έναρξης.';

  @override
  String get importWarningAdjustedEnd =>
      'Προσαρμόστηκε ώρα λήξης που δεν ήταν μετά την έναρξη.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Μη υποστηριζόμενα πεδία ICS προστέθηκαν στις σημειώσεις: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Αγνοήθηκε μη υποστηριζόμενη συχνότητα επανάληψης: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Επιλογή ημερολογίων για αντιγραφή ως ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Επιλογή ημερολογίων για εξαγωγή ως ICS';

  @override
  String get exportIcsText => 'Εξαγωγή κειμένου ICS';

  @override
  String get exportJsonText => 'Εξαγωγή κειμένου JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Τα δεδομένα της εφαρμογής επαναφέρθηκαν από το προηγούμενο αντίγραφο ασφαλείας, επειδή δεν ήταν δυνατή η φόρτωση του κύριου αρχείου.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Το κύριο αρχείο δεδομένων και το αντίγραφο ασφαλείας του έχουν καταστραφεί. Η εφαρμογή χρησιμοποιεί πλέον νέα δεδομένα.';

  @override
  String get dataRecoveryCorruptTitle => 'Τα δεδομένα σας χρειάζονται ανάκτηση';

  @override
  String get dataRecoveryCorruptMessage =>
      'Το Sked δεν μπόρεσε να διαβάσει το κύριο αρχείο δεδομένων ή το αντίγραφο ασφαλείας του. Δημιουργήθηκαν προστατευμένα αντίγραφα πριν απενεργοποιηθεί η εγγραφή.';

  @override
  String get dataRecoveryIoFailureTitle =>
      'Ο αποθηκευτικός χώρος δεν είναι διαθέσιμος';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Το Sked δεν έχει πρόσβαση στον τοπικό αποθηκευτικό χώρο αυτή τη στιγμή. Ελέγξτε την πρόσβαση ή τη διαθεσιμότητα της συσκευής και δοκιμάστε ξανά. Τα υπάρχοντα δεδομένα δεν θα αντικατασταθούν.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Ενημερώστε το Sked για να ανοίξετε αυτά τα δεδομένα';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Αυτά τα δεδομένα δημιουργήθηκαν από νεότερη έκδοση του Sked. Ενημερώστε την εφαρμογή πριν δοκιμάσετε ξανά. Η έναρξη με νέα δεδομένα έχει απενεργοποιηθεί για την προστασία τους.';

  @override
  String get dataRecoveryRetryAction => 'Δοκιμή ξανά';

  @override
  String get dataRecoveryArtifactsHint =>
      'Τα αρχεία ανάκτησης ή οι επηρεαζόμενες θέσεις αποθήκευσης αναφέρονται παρακάτω. Μην αλλάξετε κανένα αρχείο μέχρι να ανακτηθούν τα δεδομένα σας.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Εμφάνιση αρχείων και θέσεων ανάκτησης';

  @override
  String get dataRecoveryStartFreshAction => 'Έναρξη με νέα δεδομένα';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Έναρξη με νέα δεδομένα;';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Τα προστατευμένα αντίγραφα θα διατηρηθούν, αλλά το Sked θα δημιουργήσει ένα νέο τοπικό αρχείο δεδομένων. Συνεχίστε μόνο αν δεν θέλετε να δοκιμάσετε πρώτα ξανά την ανάκτηση.';

  @override
  String get previousMonth => 'Προηγούμενος μήνας';

  @override
  String get nextMonth => 'Επόμενος μήνας';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes λεπτά';
  }

  @override
  String get reminderInProgress => 'Σε εξέλιξη';

  @override
  String get deleteCourseTitle => 'Διαγραφή μαθήματος';

  @override
  String get deleteCourseMessage => 'Να διαγραφεί αυτό το μάθημα;';

  @override
  String get showLunarCalendar => 'Εμφάνιση σεληνιακού ημερολογίου';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count συμβάντα';
  }

  @override
  String get defaultView => 'Προεπιλεγμένη προβολή';

  @override
  String get generalDefaultViewSection => 'Κατά την εκκίνηση';

  @override
  String get generalViewSwitchBehavior => 'Κουμπί αλλαγής προβολής';

  @override
  String get settingsWorkspaceMode => 'Ενεργός χώρος εργασίας';

  @override
  String get hideHomeWorkspaceNavigation => 'Απόκρυψη πλοήγησης χώρων εργασίας';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Απόκρυψη πλοήγησης χώρων εργασίας. Η εναλλαγή παραμένει διαθέσιμη από το μενού της κύριας οθόνης.';

  @override
  String get generalDateLabelFormat => 'Μορφή ετικέτας ημερομηνίας';

  @override
  String get generalDateLabelFormatLocalized => 'Τοπική μορφή (Ιούλ 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Με κάθετο (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Διάταξη γραμμής εργαλείων';

  @override
  String get toolbarNavigationSection => 'Πλοήγηση γραμμής εργαλείων';

  @override
  String get toolbarNavigationHiddenBehavior => 'Κρυφά στοιχεία';

  @override
  String get toolbarNavigationRemove => 'Πλήρης απόκρυψη';

  @override
  String get toolbarNavigationMore => 'Μεταφορά στα Περισσότερα';

  @override
  String get toolbarNavigationReorder =>
      'Αναδιάταξη στοιχείων γραμμής εργαλείων';

  @override
  String get toolbarNavigationVisibility =>
      'Εμφάνιση στοιχείου γραμμής εργαλείων';

  @override
  String get toolbarNavigationTimetable => 'Επιλογή προγράμματος μαθημάτων';

  @override
  String get toolbarNavigationWeek => 'Επιλογή εβδομάδας';

  @override
  String get toolbarNavigationView => 'Αλλαγή προβολής';

  @override
  String get toolbarNavigationCategory => 'Επιλογή κατηγορίας';

  @override
  String get toolbarNavigationDate => 'Επιλογή ημερομηνίας';

  @override
  String get generalToolbarWidthPolicy => 'Κατανομή χώρου γραμμής εργαλείων';

  @override
  String get generalToolbarWidthContent => 'Αυτόματη κατανομή';

  @override
  String get generalToolbarWidthBalanced => 'Ισομερής';

  @override
  String get generalToolbarWidthCalendarPriority => 'Προτεραιότητα κατηγορίας';

  @override
  String get generalToolbarWidthDatePriority => 'Προτεραιότητα ημερομηνίας';

  @override
  String get generalViewSwitchCycle => 'Κυκλική εναλλαγή προβολών';

  @override
  String get generalViewSwitchMenu => 'Άνοιγμα μενού προβολών';

  @override
  String get generalViewSwitchTooltip => 'Αλλαγή προβολής';

  @override
  String get generalViewSwitchMenuTooltip => 'Επιλογή προβολής';

  @override
  String get generalViewLongPressTodayHint =>
      'Πατήστε παρατεταμένα για μετάβαση στο σήμερα';

  @override
  String get generalScheduleDisplaySection => 'Εμφάνιση προγράμματος';

  @override
  String get generalTimeGridSection => 'Πλέγμα ώρας';

  @override
  String get generalPopupSection => 'Συμπεριφορά αναδυόμενων παραθύρων';

  @override
  String get quickActionsSection => 'Γρήγορες ενέργειες';

  @override
  String get showAddCourseFab =>
      'Εμφάνιση αιωρούμενου κουμπιού προσθήκης μαθήματος';

  @override
  String get showAddCourseFabHint =>
      'Εμφάνιση ή απόκρυψη του αιωρούμενου κουμπιού προσθήκης μαθήματος στην κάτω δεξιά γωνία του προγράμματος μαθημάτων.';

  @override
  String get showAddEventFab =>
      'Εμφάνιση αιωρούμενου κουμπιού προσθήκης συμβάντος';

  @override
  String get showAddEventFabHint =>
      'Εμφάνιση ή απόκρυψη του αιωρούμενου κουμπιού προσθήκης συμβάντος στην κάτω δεξιά γωνία του προγράμματος.';

  @override
  String get enableLongPressAddCourse =>
      'Παρατεταμένο πάτημα σε κενό κελί για προσθήκη μαθήματος';

  @override
  String get enableLongPressAddCourseHint =>
      'Πατήστε παρατεταμένα σε μια κενή περιοχή του πλέγματος του προγράμματος μαθημάτων για να προσθέσετε μάθημα.';

  @override
  String get enableLongPressAddEvent =>
      'Παρατεταμένο πάτημα σε κενό κελί για προσθήκη συμβάντος';

  @override
  String get enableLongPressAddEventHint =>
      'Στην ημερήσια ή εβδομαδιαία προβολή, πατήστε παρατεταμένα σε μια κενή περιοχή του πλέγματος ώρας για να προσθέσετε συμβάν.';

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
  String get developerNotificationDiagnostics => 'Διαγνωστικά ειδοποιήσεων';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Ελέγξτε την κατάσταση παράδοσης στο Android, αναδημιουργήστε το υπάρχον πλάνο υπενθυμίσεων και στείλτε ασφαλείς δοκιμαστικές ειδοποιήσεις μέσω της κανονικής υπηρεσίας ειδοποιήσεων του Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Τα διαγνωστικά ειδοποιήσεων είναι διαθέσιμα μόνο στο Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Τα διαγνωστικά ειδοποιήσεων θα είναι διαθέσιμα όταν ξεκινήσει ο συντονιστής προγράμματος.';

  @override
  String get developerNotificationRefresh => 'Ανανέωση διαγνωστικών';

  @override
  String get developerNotificationSystemStatus =>
      'Άδεια ειδοποιήσεων συστήματος';

  @override
  String get developerNotificationPermissionAllowed => 'Επιτρέπεται';

  @override
  String get developerNotificationPermissionBlocked => 'Αποκλεισμένη';

  @override
  String get developerNotificationExactAlarm => 'Ακριβή ξυπνητήρια';

  @override
  String get developerNotificationExactAlarmAllowed => 'Επιτρέπονται';

  @override
  String get developerNotificationExactAlarmBlocked => 'Δεν επιτρέπονται';

  @override
  String get developerNotificationPlan => 'Πλάνο ειδοποιήσεων προγράμματος';

  @override
  String get developerNotificationCoverage => 'Κάλυψη υπενθυμίσεων';

  @override
  String get developerNotificationCoverageReady =>
      'Όλες οι γνωστές υπενθυμίσεις με πεπερασμένο αριθμό επαναλήψεων έχουν προγραμματιστεί απευθείας';

  @override
  String get developerNotificationCoverageRenewable =>
      'Γίνεται προσπάθεια συνεχούς ανανέωσης των επαναλαμβανόμενων υπενθυμίσεων για μακροχρόνια κάλυψη';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Το όριο άμεσου προγραμματισμού έχει καλυφθεί. Θα επιχειρηθεί ανανέωση των επόμενων υπενθυμίσεων';

  @override
  String get developerNotificationCoverageBlocked =>
      'Δεν πληρούνται οι προϋποθέσεις ακριβούς παράδοσης';

  @override
  String get developerNotificationCoverageFailed =>
      'Ο τελευταίος συγχρονισμός υπενθυμίσεων απέτυχε';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled απευθείας προγραμματισμένες / όριο $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled προγραμματισμένες, $planned στο πλάνο';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Τελευταίο σφάλμα: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Αναδημιουργία πλάνου ειδοποιήσεων';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Το πλάνο ειδοποιήσεων αναδημιουργήθηκε.';

  @override
  String get developerNotificationTestChannel => 'Κανάλι δοκιμής';

  @override
  String get developerNotificationTestCourse => 'Υπενθυμίσεις μαθημάτων';

  @override
  String get developerNotificationTestSchedule => 'Υπενθυμίσεις συμβάντων';

  @override
  String get developerNotificationImmediateTest =>
      'Αποστολή άμεσης δοκιμαστικής ειδοποίησης';

  @override
  String get developerNotificationThirtySecondTest =>
      'Προγραμματισμός δοκιμής στο παρασκήνιο σε 30 δευτερόλεπτα';

  @override
  String get developerNotificationImmediateQueued =>
      'Στάλθηκε άμεση δοκιμαστική ειδοποίηση.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Προγραμματίστηκε δοκιμή στο παρασκήνιο σε 30 δευτερόλεπτα.';

  @override
  String get developerNotificationAppSwitch =>
      'Διακόπτης υπενθυμίσεων εφαρμογής';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Οι κανονικές υπενθυμίσεις είναι ενεργοποιημένες';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Οι κανονικές υπενθυμίσεις είναι απενεργοποιημένες. Οι δοκιμές προγραμματιστή μπορούν να εκτελεστούν';

  @override
  String get developerNotificationTimeZone => 'Τοπική ζώνη ώρας';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Δεν έχει δημιουργηθεί ακόμα. Θα δημιουργηθεί με μια δοκιμή προγραμματιστή.';

  @override
  String get developerNotificationChannelEnabledState => 'Ενεργοποιημένο';

  @override
  String get developerNotificationChannelBlockedState => 'Αποκλεισμένο';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Σημαντικότητα: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Η σημαντικότητα δεν είναι διαθέσιμη';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending σε αναμονή / $active ενεργές';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Τελευταία εμφάνιση από το σύστημα: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Δεν έχει καταγραφεί ακόμα επανυπολογισμός.';

  @override
  String get developerNotificationNextReminder => 'Επόμενη κανονική υπενθύμιση';

  @override
  String get developerNotificationNoPendingReminder =>
      'Δεν υπάρχει μελλοντική υπενθύμιση στο τρέχον πλάνο';

  @override
  String get developerNotificationNextMaintenance => 'Επόμενη συντήρηση';

  @override
  String get developerNotificationNextRenewal => 'Επόμενη προσπάθεια ανανέωσης';

  @override
  String get developerNotificationNoMaintenance => 'Δεν έχει προγραμματιστεί';

  @override
  String get developerNotificationTruncation => 'Περικοπή πλάνου';

  @override
  String developerNotificationTruncationCount(int count) {
    return 'Παραλείφθηκαν $count λόγω του ορίου του πλάνου';
  }

  @override
  String get developerNotificationLastReconciliation =>
      'Τελευταίος επανυπολογισμός';

  @override
  String get developerNotificationLastSynchronization =>
      'Τελευταίος συγχρονισμός υπενθυμίσεων';

  @override
  String get developerNotificationLateRecovery =>
      'Ανάκτηση καθυστερημένων υπενθυμίσεων';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return 'Ανακτήθηκαν και παραδόθηκαν $count υπενθυμίσεις μετά την αρχικά προγραμματισμένη ώρα τους';
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
  String get developerNotificationReconcileOriginForeground => 'Προσκήνιο';

  @override
  String get developerNotificationReconcileOriginBackground => 'Παρασκήνιο';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Πλήρης επανυπολογισμός';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Συντήρηση';

  @override
  String get developerNotificationReconcileModeRecovery => 'Ανάκτηση';

  @override
  String get developerNotificationRunRecovery =>
      'Εκτέλεση ανάκτησης υπενθυμίσεων';

  @override
  String get developerNotificationRecoveryComplete =>
      'Η ανάκτηση υπενθυμίσεων ολοκληρώθηκε';

  @override
  String get developerNotificationReconcileResultSuccess => 'Επιτυχία';

  @override
  String get developerNotificationReconcileResultSkipped => 'Παραλείφθηκε';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Ο προγραμματισμός αναστέλλεται μέχρι να πληρούνται όλες οι προϋποθέσεις ακριβούς παράδοσης';

  @override
  String get developerNotificationReconcileResultFailed => 'Αποτυχία';

  @override
  String get developerNotificationBackgroundLimits =>
      'Περιορισμοί παρασκηνίου του κατασκευαστή';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Οι περιορισμοί παρασκηνίου του κατασκευαστή ενδέχεται να επηρεάζουν την παράδοση.';

  @override
  String get developerNotificationAutostart =>
      'Εκκίνηση στο παρασκήνιο από τον κατασκευαστή';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Κατασκευαστής: $vendor. Υπάρχει πρόσβαση στις ρυθμίσεις του κατασκευαστή. Το Android δεν μπορεί να αναφέρει την κατάσταση αυτής της άδειας.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Κατασκευαστής: $vendor. Χρησιμοποιείται η σελίδα πληροφοριών εφαρμογής. Το Android δεν μπορεί να αναφέρει την κατάσταση αυτής της άδειας.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Δεν υπάρχει διαθέσιμη πρόσβαση στις ρυθμίσεις παρασκηνίου του κατασκευαστή.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Τελευταία σελίδα που ανοίχτηκε: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'ρυθμίσεις κατασκευαστή';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'πληροφορίες εφαρμογής';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'καμία';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Περιορισμοί ανάκτησης μετά από επανεκκίνηση';

  @override
  String get developerNotificationRebootBoundary =>
      'Η ανάκτηση ξεκινά μετά το πρώτο ξεκλείδωμα. Μια εφαρμογή που έχει διακοπεί αναγκαστικά δεν μπορεί να ξεκινήσει αυτόματα.';

  @override
  String get developerNotificationTestChecking =>
      'Οι δοκιμές δεν είναι διαθέσιμες όσο ελέγχεται η κατάσταση των ειδοποιήσεων.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Οι δοκιμές δεν είναι διαθέσιμες επειδή οι ειδοποιήσεις συστήματος είναι αποκλεισμένες.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Οι δοκιμές δεν είναι διαθέσιμες επειδή το επιλεγμένο κανάλι ειδοποιήσεων είναι αποκλεισμένο.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Διαχείριση από τις ρυθμίσεις ειδοποιήσεων των Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Δεν ισχύει στα Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Ταυτότητα πακέτου Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Υπάρχει ταυτότητα MSIX. Οι εμφανιζόμενες ειδοποιήσεις μπορούν να αποσυρθούν';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Εγκαταστήστε την έκδοση MSIX για αξιόπιστη απόσυρση εμφανιζόμενων ειδοποιήσεων';

  @override
  String get collapseWorkspaceNavigation => 'Σύμπτυξη πλοήγησης χώρου εργασίας';

  @override
  String get expandWorkspaceNavigation => 'Ανάπτυξη πλοήγησης χώρου εργασίας';

  @override
  String get schoolWebImportExitBrowser =>
      'Έξοδος από το ενσωματωμένο πρόγραμμα περιήγησης';

  @override
  String get schoolWebImportEditAddress => 'Επεξεργασία διεύθυνσης';

  @override
  String get schoolWebImportAddressLabel => 'Διεύθυνση ιστού';

  @override
  String get schoolWebImportOpenAddress => 'Άνοιγμα';

  @override
  String get schoolWebImportAddressInvalid =>
      'Εισαγάγετε μια διεύθυνση HTTP ή HTTPS με κεντρικό υπολογιστή.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Αυτή η ιστοσελίδα ζήτησε νέο παράθυρο, το οποίο δεν μπορεί να ανοίξει σε αυτήν τη συσκευή.';

  @override
  String get schoolWebImportSecureConnection => 'Ασφαλής σύνδεση';

  @override
  String get schoolWebImportInsecureConnection => 'Μη ασφαλής σύνδεση';

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
  String get notificationSettingsSection => 'Υπενθυμίσεις και ειδοποιήσεις';

  @override
  String get notificationCoverage => 'Κάλυψη υπενθυμίσεων';

  @override
  String get notificationCoverageRenewable =>
      'Τα επαναλαμβανόμενα συμβάντα χωρίς ημερομηνία λήξης χρησιμοποιούν ανανέωση στο παρασκήνιο για μακροχρόνια κάλυψη.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Το Android μπορεί να προγραμματίσει απευθείας έως $capacity υπενθυμίσεις. Για τις επόμενες γίνεται προσπάθεια ανανέωσης εκ των προτέρων.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Ενεργοποίηση υπενθυμίσεων και ειδοποιήσεων';

  @override
  String get notificationSettingsEnabledHint =>
      'Προγραμματίζονται ειδοποιήσεις μόνο για στοιχεία με υπενθύμιση. Ορίστε παρακάτω μια προεπιλεγμένη υπενθύμιση για τα μαθήματα που τη χρησιμοποιούν.';

  @override
  String get notificationPrecisionLimitations =>
      'Οι υπενθυμίσεις εξαρτώνται από τα δικαιώματα και την εκτέλεση στο παρασκήνιο. Τερματισμός, αλλαγές ώρας ή περιορισμοί συστήματος μπορεί να τις καθυστερήσουν.';

  @override
  String get notificationSettingsEnabledSummary => 'Ενεργοποιημένες';

  @override
  String get notificationSettingsDisabledSummary => 'Απενεργοποιημένες';

  @override
  String get notificationDefaultsSection => 'Προεπιλεγμένες υπενθυμίσεις';

  @override
  String get notificationCourseDefaultReminder =>
      'Προεπιλεγμένη υπενθύμιση μαθημάτων';

  @override
  String get notificationGeneralDefaultReminder =>
      'Προεπιλεγμένη υπενθύμιση συμβάντων';

  @override
  String get notificationReminderOff => 'Χωρίς υπενθύμιση';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes λεπτά πριν';
  }

  @override
  String get notificationPermission => 'Άδεια ειδοποιήσεων';

  @override
  String get notificationPermissionGranted => 'Επιτρέπεται από το σύστημα';

  @override
  String get notificationPermissionDenied => 'Αποκλεισμένη από το σύστημα';

  @override
  String get notificationPermissionChecking => 'Έλεγχος άδειας…';

  @override
  String get notificationPermissionRequest => 'Αίτημα άδειας';

  @override
  String get notificationPermissionOpenSettings =>
      'Άνοιγμα ρυθμίσεων συστήματος';

  @override
  String get notificationPermissionRequestFailed =>
      'Δεν ήταν δυνατή η ανάγνωση της άδειας ειδοποιήσεων. Δοκιμάστε ξανά.';

  @override
  String get notificationExactAlarm => 'Άδεια ακριβών ξυπνητηριών';

  @override
  String get notificationExactAlarmAllowed => 'Επιτρέπεται από το σύστημα';

  @override
  String get notificationExactAlarmRequired =>
      'Απαιτείται για υπενθυμίσεις σε ακριβή ώρα';

  @override
  String get notificationExactAlarmRequest =>
      'Να επιτρέπονται ακριβή ξυπνητήρια';

  @override
  String get notificationBatteryOptimization => 'Βελτιστοποίηση μπαταρίας';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Έχει οριστεί εξαίρεση από τη βελτιστοποίηση μπαταρίας του Android';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Οι ακριβείς υπενθυμίσεις απαιτούν εξαίρεση από τη βελτιστοποίηση μπαταρίας του Android';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Άνοιγμα ρυθμίσεων βελτιστοποίησης μπαταρίας';

  @override
  String get notificationAutostart =>
      'Εκκίνηση στο παρασκήνιο από τον κατασκευαστή';

  @override
  String get notificationAutostartVendorHint =>
      'Επιτρέψτε την αυτόματη εκκίνηση ή τη λειτουργία στο παρασκήνιο, ώστε οι υπενθυμίσεις να επαναφέρονται μετά από επανεκκίνηση.';

  @override
  String get notificationAutostartFallbackHint =>
      'Ανοίξτε τις πληροφορίες εφαρμογής του Sked και επιτρέψτε τη λειτουργία στο παρασκήνιο. Το Android δεν μπορεί να ελέγξει αυτή τη ρύθμιση του κατασκευαστή.';

  @override
  String get notificationAutostartUnavailable =>
      'Δεν βρέθηκε σελίδα ρυθμίσεων του κατασκευαστή. Ελέγξτε χειροκίνητα τις πληροφορίες εφαρμογής του Sked.';

  @override
  String get notificationAutostartRequest =>
      'Άνοιγμα ρυθμίσεων παρασκηνίου του κατασκευαστή';

  @override
  String get notificationAutostartOpenFailed =>
      'Δεν ήταν δυνατό το άνοιγμα των ρυθμίσεων παρασκηνίου του κατασκευαστή. Ελέγξτε χειροκίνητα τις πληροφορίες εφαρμογής του Sked.';

  @override
  String get notificationLockScreenTitles =>
      'Εμφάνιση τίτλων στην οθόνη κλειδώματος';

  @override
  String get notificationLockScreenTitlesHint =>
      'Όταν είναι απενεργοποιημένο, οι λεπτομέρειες ειδοποιήσεων αποκρύπτονται στην οθόνη κλειδώματος.';

  @override
  String get notificationWidgets => 'Γραφικά στοιχεία αρχικής οθόνης';

  @override
  String get notificationWidgetsDesc =>
      'Ανανεώστε τα γραφικά στοιχεία του Sked και μάθετε πώς να προσθέσετε ένα στην αρχική οθόνη.';

  @override
  String get notificationWidgetsDialogTitle =>
      'Προσθήκη γραφικού στοιχείου Sked';

  @override
  String get notificationWidgetsDialogMessage =>
      'Στην αρχική οθόνη της συσκευής, πατήστε παρατεταμένα σε μια κενή περιοχή, επιλέξτε «Γραφικά στοιχεία» και προσθέστε ένα γραφικό στοιχείο Sked. Θα εμφανίζει τα επόμενα μαθήματα ή συμβάντα σας.';

  @override
  String get notificationWidgetsRefresh => 'Ανανέωση γραφικών στοιχείων';

  @override
  String get notificationWidgetsRefreshed => 'Τα γραφικά στοιχεία ανανεώθηκαν';

  @override
  String get notificationPlatformUnsupported =>
      'Αυτή η πλατφόρμα δεν παρέχει εγγενείς ειδοποιήσεις.';

  @override
  String get workspaceFeatures => 'Διαχείριση λειτουργιών';

  @override
  String get workspaceBoth => 'Ωρολόγιο πρόγραμμα και ημερολόγιο';

  @override
  String get workspaceOnlyStudent => 'Μόνο ωρολόγιο πρόγραμμα';

  @override
  String get workspaceOnlyGeneral => 'Μόνο ημερολόγιο';

  @override
  String get workspaceDisableTitle =>
      'Απενεργοποίηση αυτού του χώρου εργασίας;';

  @override
  String get workspaceDisableMessage =>
      'Τα δεδομένα και οι προτιμήσεις διατηρούνται. Οι λειτουργίες και οι υπενθυμίσεις θα σταματήσουν μέχρι να τον ενεργοποιήσετε ξανά εδώ.';

  @override
  String get workspaceEnableHint =>
      'Επιλέξτε τις λειτουργίες που χρησιμοποιείτε. Τουλάχιστον μία πρέπει να παραμείνει ενεργή.';

  @override
  String get workspaceLastRequired =>
      'Τουλάχιστον ένας χώρος εργασίας πρέπει να παραμείνει ενεργός.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Ο χώρος εργασίας απενεργοποιήθηκε, αλλά οι υπενθυμίσεις δεν καταργήθηκαν. Δοκιμάστε ξανά την ανάκτηση ειδοποιήσεων.';

  @override
  String get settingsSearch => 'Αναζήτηση ρυθμίσεων';

  @override
  String get settingsNoResults => 'Δεν βρέθηκαν αντίστοιχες ρυθμίσεις';

  @override
  String get settingsDataPrivacy => 'Δεδομένα και απόρρητο';

  @override
  String get workspacePreferences => 'Εμφάνιση και αλληλεπίδραση';

  @override
  String get workspaceManage => 'Διαχείριση';

  @override
  String get selectedDayAgenda => 'Επιλεγμένη ημέρα';

  @override
  String get notificationTroubleshooting =>
      'Δικαιώματα και αντιμετώπιση προβλημάτων';

  @override
  String get settingsConnection => 'Σύνδεση';

  @override
  String get settingsAdvanced => 'Για προχωρημένους';

  @override
  String get unsavedChangesMessage =>
      'Υπάρχουν μη αποθηκευμένες αλλαγές. Να απορριφθούν και να γίνει έξοδος;';

  @override
  String get backupWorkspaceSelection =>
      'Το πλήρες αντίγραφο ασφαλείας περιλαμβάνει δεδομένα και την επιλογή ενεργών χώρων εργασίας.';

  @override
  String get assistantLayoutPreview => 'AI · Προεπισκόπηση διάταξης';

  @override
  String get assistantSelectionContext =>
      'Χρησιμοποιεί την τρέχουσα επιλογή ως πλαίσιο';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Πρόχειρο μηνύματος';

  @override
  String get assistantPreviewNoSend =>
      'Μόνο προεπισκόπηση διάταξης. Δεν θα σταλεί ή θα αλλάξει τίποτα.';

  @override
  String get resizePanel => 'Αλλαγή μεγέθους πίνακα';

  @override
  String get minimizeWindow => 'Ελαχιστοποίηση';

  @override
  String get maximizeWindow => 'Μεγιστοποίηση';

  @override
  String get restoreWindow => 'Επαναφορά παραθύρου';

  @override
  String get closeWindow => 'Κλείσιμο παραθύρου';

  @override
  String get courseSystemReminder => 'Υπενθύμιση συστήματος';

  @override
  String courseReminderInherit(String reminder) {
    return 'Χρήση προεπιλογής ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Οι υπενθυμίσεις συστήματος είναι απενεργοποιημένες στις ρυθμίσεις ειδοποιήσεων. Η προτίμηση για αυτό το μάθημα μπορεί να αποθηκευτεί.';

  @override
  String get courseReminderDefaultOff =>
      'Δεν έχει οριστεί προεπιλεγμένη υπενθύμιση μαθημάτων. Επιλέξτε εδώ μια προσαρμοσμένη υπενθύμιση ή ορίστε μια προεπιλογή στις ρυθμίσεις ειδοποιήσεων.';

  @override
  String get courseReminderDeliveryHint =>
      'Αυτή η προτίμηση αποθηκεύεται με το μάθημα. Η παράδοση εξαρτάται από τις άδειες ειδοποιήσεων του συστήματος και τους περιορισμούς παρασκηνίου.';

  @override
  String get courseReminderPermissionUnknown =>
      'Η κατάσταση των ειδοποιήσεων συστήματος δεν έχει ελεγχθεί. Ελέγξτε τις ρυθμίσεις ειδοποιήσεων πριν βασιστείτε στις υπενθυμίσεις.';

  @override
  String get courseReminderMinutesLabel => 'Λεπτά πριν από το μάθημα';

  @override
  String get exportAction => 'Εξαγωγή';

  @override
  String get datePickerSelectWeek => 'Επιλογή εβδομάδας';

  @override
  String get datePickerSelectMonth => 'Επιλογή μήνα';

  @override
  String get generalDateLabelFormatDescription =>
      'Ισχύει για την πλοήγηση ημερομηνιών σε υπολογιστές και μικρότερες οθόνες.';

  @override
  String get dateRangeTitle => 'Επιλογή εύρους ημερομηνιών';

  @override
  String get dateRangeCustom => 'Προσαρμοσμένο';

  @override
  String get dateRangeChooseStart => 'Επιλέξτε ημερομηνία έναρξης';

  @override
  String get dateRangeChooseEnd => 'Επιλέξτε ημερομηνία λήξης';

  @override
  String get dateRangeLimit =>
      'Επιλέξτε 1–14 ημέρες, μαζί με την αρχική και την τελική.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ημέρες',
      one: '1 ημέρα',
    );
    return 'Προσαρμοσμένο · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Επιλογή με τροχούς κύλισης';

  @override
  String get courseReminderUseDefault => 'Χρήση προεπιλογής';

  @override
  String get courseReminderInvalidMinutes =>
      'Εισαγάγετε ακέραιο αριθμό λεπτών, μηδέν ή μεγαλύτερο.';

  @override
  String get generalCustomColumnWidth =>
      'Πλάτος στηλών προσαρμοσμένης προβολής';

  @override
  String get generalCustomColumnWidthAuto => 'Αυτόματο';

  @override
  String get generalCustomColumnWidthManual => 'Ελάχιστο πλάτος';

  @override
  String get generalCustomColumnWidthMinimum => 'Ελάχιστο πλάτος ανά ημέρα';

  @override
  String get generalCustomColumnWidthHint =>
      'Όλες οι ημερομηνίες έχουν το ίδιο ελάχιστο πλάτος. Οι στήλες γεμίζουν τον διαθέσιμο χώρο ή μετακινούνται οριζόντια. Επηρεάζει μόνο την προσαρμοσμένη προβολή.';

  @override
  String get settingsAppearanceLanguage => 'Εμφάνιση και γλώσσα';

  @override
  String get settingsAppearanceDetails => 'Χρώματα και περιγράμματα';

  @override
  String get monthNoEvents => 'Δεν υπάρχουν συμβάντα αυτή την ημέρα';

  @override
  String get settingsOverview => 'Επισκόπηση';

  @override
  String get settingsThemeTarget => 'Θέμα για';

  @override
  String get settingsColorMode => 'Λειτουργία χρώματος';

  @override
  String get settingsNotificationPreferences => 'Προτιμήσεις υπενθυμίσεων';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Προεπιλεγμένες υπενθυμίσεις, άδειες και αξιοπιστία';

  @override
  String get settingsFeaturesSummary => 'Χώροι εργασίας και πλοήγηση';

  @override
  String get settingsPrivacySummary =>
      'Πολιτική απορρήτου και εκκαθάριση τοπικών δεδομένων';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count διδακτικές ώρες',
      one: '1 διδακτική ώρα',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Διδακτική ώρα';

  @override
  String get periodTimesDurationColumn => 'Διάρκεια';

  @override
  String get periodTimesGapColumn => 'Διάλειμμα';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes λεπτά';
  }

  @override
  String get periodTimesSavePending => 'Αναμονή αποθήκευσης…';

  @override
  String get periodTimesSaveFailed => 'Δεν αποθηκεύτηκε · Η αποθήκευση απέτυχε';

  @override
  String get periodTimesInvalidStatus =>
      'Δεν αποθηκεύτηκε · Διορθώστε τις επισημασμένες ώρες';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Το Sked δεν μπόρεσε να επιβεβαιώσει αν αναιρέθηκε η τελευταία αποθήκευση. Οι εγγραφές έχουν ανασταλεί και διατηρούνται αντίγραφα ανάκτησης. Ελέγξτε τον χώρο αποθήκευσης και δοκιμάστε ξανά τη φόρτωση.';

  @override
  String get settingsPanelDisplayMode => 'Εμφάνιση πλαισίων';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Κοινή για ωρολόγια προγράμματα και ημερολόγια';

  @override
  String get settingsPanelDisplayOverlay => 'Επικάλυψη';

  @override
  String get settingsPanelDisplaySideBySide => 'Δίπλα δίπλα';

  @override
  String get settingsPanelDisplayAutomatic => 'Αυτόματα';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Επικαλύπτει τη δεξιά πλευρά χωρίς να αλλάζει το πλάτος του ημερολογίου.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Προτιμά δίπλα δίπλα· επικαλύπτει μόνο αν το ημερολόγιο γίνει πολύ στενό.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Εμφανίζει δίπλα δίπλα όταν το ημερολόγιο παραμένει ευανάγνωστο, αλλιώς επικαλύπτει.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Η απενεργοποίηση των Ρυθμίσεων ή του Χώρου εργασίας στη γραμμή εργαλείων τα μεταφέρει στα Περισσότερα αντί να τα αφαιρέσει. Τα Περισσότερα δεν μπορούν να κρυφτούν όσο περιέχουν απαραίτητες ενέργειες. Η εναλλαγή χώρων εργασίας εμφανίζεται μόνο όταν η κάτω πλοήγηση είναι κρυφή και είναι ενεργοποιημένοι πολλοί χώροι εργασίας.';

  @override
  String get reminderEnded => 'Ολοκληρώθηκε';

  @override
  String get reminderAutoCloseHint =>
      'Κλείνει μετά από 10 δευτερόλεπτα. Αλληλεπιδράστε για να παραμείνει ανοιχτό.';

  @override
  String get showReminderIndependently => 'Άνοιγμα ξεχωριστά';

  @override
  String get categoryManagerTitle => 'Διαχείριση κατηγοριών';

  @override
  String get categoryHidden => 'Κρυφή';

  @override
  String get categoryShowOnCalendar => 'Εμφάνιση στο ημερολόγιο';

  @override
  String get categoryHideOnCalendar => 'Απόκρυψη από το ημερολόγιο';

  @override
  String get categoryEditColor => 'Αλλαγή χρώματος κατηγορίας';

  @override
  String get categoryThemePalette => 'Παλέτα θέματος';

  @override
  String get categoryCustomColor => 'Προσαρμοσμένο';

  @override
  String get colorHexInvalid =>
      'Εισαγάγετε εξαψήφιο δεκαεξαδικό κωδικό χρώματος.';

  @override
  String categoryColorSlot(int number) {
    return 'Χρώμα θέματος $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Οι ενημερώσεις του καταστήματος ενδέχεται να καθυστερήσουν. Η διαθεσιμότητα καθορίζεται από τη σελίδα του καταστήματος.';

  @override
  String get storePrereleaseNotice =>
      'Η λήψη ειδοποιήσεων για προκαταρκτικές εκδόσεις δεν σας εγγράφει σε πρόγραμμα δοκιμών του καταστήματος.';

  @override
  String get updateFoundTitle => 'Διαθέσιμη νέα έκδοση';

  @override
  String get updateNoNotes => 'Δεν έχουν δοθεί σημειώσεις έκδοσης.';

  @override
  String get updateLater => 'Αργότερα';

  @override
  String get updateRetry => 'Δοκιμή ξανά';

  @override
  String get updatePrerelease => 'Προκαταρκτική έκδοση';

  @override
  String get updateNetworkFailure =>
      'Δεν ήταν δυνατός ο έλεγχος για ενημερώσεις. Ελέγξτε τη σύνδεσή σας και δοκιμάστε ξανά.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Δεν βρέθηκε νεότερη έκδοση (τρέχουσα: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Επαναφορά αντιγράφου ασφαλείας…';

  @override
  String get backupRestoreInProgressMessage =>
      'Τα δεδομένα και οι ρυθμίσεις μπορούν να αλλάξουν όταν ολοκληρωθεί η επαναφορά. Μπορείτε ακόμα να τα προβάλετε.';
}
