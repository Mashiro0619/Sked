import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/timetable_course_week_status.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final height in [20.0, 300.0]) {
      testWidgets(
        'a status with no retained glyphs keeps a visible marker: $direction $height',
        (tester) async {
          const width = 6.0;
          const boundsKey = ValueKey('course-bounds');
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      key: boundsKey,
                      width: width,
                      height: height,
                      child: const TimetableCourseWeekStatus(
                        title: 'Physics',
                        label: 'Off week',
                        titleStyle: TextStyle(fontFamily: 'Ahem', fontSize: 12),
                        style: TextStyle(fontFamily: 'Ahem', fontSize: 12),
                        child: SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final bounds = tester.getRect(find.byKey(boundsKey));
          expect(bounds.size, Size(width, height));
          final marker = find.byIcon(Icons.more_horiz);
          expect(marker, findsOneWidget);
          final markerRect = tester.getRect(marker);
          expect(markerRect.width, greaterThan(0));
          expect(markerRect.height, greaterThan(0));
          expect(markerRect.left, greaterThanOrEqualTo(bounds.left));
          expect(markerRect.right, lessThanOrEqualTo(bounds.right));
          expect(markerRect.top, greaterThanOrEqualTo(bounds.top));
          expect(markerRect.bottom, lessThanOrEqualTo(bounds.bottom));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
