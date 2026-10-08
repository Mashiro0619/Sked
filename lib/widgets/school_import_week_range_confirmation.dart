import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../utils/time_utils.dart';
import 'expressive_dialog.dart';

Future<bool> confirmSchoolImportWeekRange(
  BuildContext context,
  SchoolImportTimetableDraft timetable,
) async {
  final totalWeeks = normalizeTimetableWeeks(timetable.totalWeeks);
  final lastCourseWeek = timetable.courses
      .expand((course) => course.semesterWeeks)
      .fold(0, (latest, week) => week > latest ? week : latest);
  if (lastCourseWeek <= totalWeeks) return true;

  return await showExpressiveDialog<bool>(
        context: context,
        barrierDismissible: false,
        waitForTransitionComplete: true,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.schoolWebImportWarnings),
            content: Text(
              '${l10n.totalWeeks}: $totalWeeks\n'
              '${l10n.schoolImportTotalWeeksTooShort(lastCourseWeek)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.schoolImportParsePageContinue),
              ),
            ],
          );
        },
      ) ??
      false;
}
