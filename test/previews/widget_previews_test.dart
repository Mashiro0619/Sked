import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/previews/period_times_editor_previews.dart';
import 'package:sked/previews/period_time_set_picker_previews.dart';
import 'package:sked/previews/settings_grouping_previews.dart';
import 'package:sked/previews/sked_preview_support.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

void main() {
  final scenarios = <String, Widget Function()>{
    'timetable information form': timetableInformationFormPreview,
    'course time range': courseTimeRangePreview,
    'period time-set editor': periodTimesEditorPreview,
    'period time-set picker': periodTimeSetPickerDialogPreview,
    'responsive settings grouping': responsiveSettingsGroupingPreview,
  };

  for (final MapEntry(:key, :value) in scenarios.entries) {
    testWidgets('$key renders on phone, 2x text, and wide viewports', (
      tester,
    ) async {
      for (final scenario in const <({Size size, double scale})>[
        (size: Size(360, 800), scale: 1),
        (size: Size(360, 900), scale: 2),
        (size: Size(1100, 760), scale: 1),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.size;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(textScaler: TextScaler.linear(scenario.scale)),
            child: skedPreviewWrapper(value()),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('preview controls remain interactive', (tester) async {
    Future<void> pumpPreview(Widget child) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 900);
      await tester.pumpWidget(skedPreviewWrapper(child));
      await tester.pump();
    }

    await pumpPreview(courseTimeRangePreview());
    await tester.tap(find.text('08:00'));
    await tester.tap(find.text('09:40'));

    await pumpPreview(periodTimeSetPickerDialogPreview());
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.tap(find.text('Short Friday'));
    await tester.tap(find.text('Cancel'));

    await pumpPreview(timetableInformationFormPreview());
    await tester.tap(find.text('2026-09-07'));
    await tester.tap(find.textContaining('Standard day'));
    await tester.tap(find.text('Delete'));
    await tester.tap(find.text('Cancel'));
    await tester.tap(find.text('Save'));
    expect(tester.takeException(), isNull);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });
}
