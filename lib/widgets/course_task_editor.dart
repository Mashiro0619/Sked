import 'package:material_ui/material_ui.dart';

import '../controllers/course_task_controller.dart';
import 'course_editor_sheet.dart';

class CourseTaskEditor extends StatelessWidget {
  const CourseTaskEditor({
    super.key,
    required this.task,
    this.dayOfWeek,
    this.initialStartMinutes,
    this.initialEndMinutes,
    this.initialPeriods,
  });

  final CourseTaskController task;
  final int? dayOfWeek;
  final int? initialStartMinutes;
  final int? initialEndMinutes;
  final List<int>? initialPeriods;

  @override
  Widget build(BuildContext context) => CourseEditorSheet(
    periodTimes: task.periodTimes,
    totalWeeks: task.totalWeeks,
    initialCourse: task.initialCourse,
    dayOfWeek: dayOfWeek ?? task.initialCourse?.dayOfWeek ?? 1,
    initialStartMinutes: initialStartMinutes,
    initialEndMinutes: initialEndMinutes,
    initialPeriods: initialPeriods,
    onSave: task.save,
    onDelete: task.initialCourse == null ? null : task.delete,
  );
}
