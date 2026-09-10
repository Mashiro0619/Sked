import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../utils/time_utils.dart';

class SchoolImportSummaryPreview extends StatelessWidget {
  const SchoolImportSummaryPreview({super.key, required this.response});
  final SchoolImportResponse response;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final timetable = response.timetable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.schoolWebImportPreview,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(timetable.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(l.schoolWebImportCourseCount(timetable.courses.length)),
        const SizedBox(height: 12),
        SizedBox(
          height: 400,
          child: ListView.separated(
            itemCount: timetable.courses.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final course = timetable.courses[index];
              final day = DateFormat.E(l.localeName)
                  .format(DateTime(2024, 1, course.dayOfWeek.clamp(1, 7)));
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(course.name),
                subtitle: Text(
                  [
                    day,
                    '${formatMinutes(course.startMinutes)}–${formatMinutes(course.endMinutes)}',
                    if (course.location.isNotEmpty) course.location,
                  ].join('  '),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
