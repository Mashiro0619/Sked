import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';

import '../models/timetable_models.dart';
import '../widgets/period_time_set_picker_dialog.dart';
import 'sked_preview_support.dart';

@Preview(
  group: 'Period time-set picker dialog',
  name: 'Phone',
  size: skedPhonePreviewSize,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Period time-set picker dialog',
  name: 'Phone - 2x text',
  size: skedPhoneLargeTextPreviewSize,
  textScaleFactor: 2,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Period time-set picker dialog',
  name: 'Wide',
  size: skedWidePreviewSize,
  wrapper: skedPreviewWrapper,
)
Widget periodTimeSetPickerDialogPreview() {
  const periodTimes = <CoursePeriodTime>[
    CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
    CoursePeriodTime(index: 2, startMinutes: 535, endMinutes: 580),
    CoursePeriodTime(index: 3, startMinutes: 600, endMinutes: 645),
    CoursePeriodTime(index: 4, startMinutes: 655, endMinutes: 700),
  ];
  return Navigator(
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => PeriodTimeSetPickerDialogView(
        periodTimeSets: const <PeriodTimeSet>[
          PeriodTimeSet(
            id: 'standard',
            name: 'Standard day',
            periodTimes: periodTimes,
          ),
          PeriodTimeSet(
            id: 'friday',
            name: 'Short Friday',
            periodTimes: periodTimes,
          ),
          PeriodTimeSet(
            id: 'exam',
            name: 'Exam schedule',
            periodTimes: periodTimes,
          ),
        ],
        selectedPeriodTimeSetId: 'standard',
        busy: false,
        blocked: false,
        onCreate: _ignorePreviewAction,
        onEdit: _ignorePeriodTimeSet,
        onSelect: _ignoreString,
        onCancel: _ignorePreviewAction,
      ),
    ),
  );
}

void _ignorePreviewAction() {}

void _ignorePeriodTimeSet(PeriodTimeSet _) {}

void _ignoreString(String _) {}
