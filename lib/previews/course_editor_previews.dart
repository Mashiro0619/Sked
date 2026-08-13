part of 'package:sked/widgets/course_editor_sheet.dart';

@Preview(
  group: 'Course time range',
  name: 'Phone',
  size: skedPhonePreviewSize,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Course time range',
  name: 'Phone - 2x text',
  size: skedPhoneLargeTextPreviewSize,
  textScaleFactor: 2,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Course time range',
  name: 'Wide',
  size: skedWidePreviewSize,
  wrapper: skedPreviewWrapper,
)
Widget courseTimeRangePreview() {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _CourseTimeRange(
          startLabel: 'Start time',
          startValue: '08:00',
          endLabel: 'End time',
          endValue: '09:40',
          enabled: true,
          onPickStart: () {},
          onPickEnd: () {},
        ),
      ),
    ),
  );
}
