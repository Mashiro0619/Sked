import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';

import '../support/workspace_harness.dart';

const _calendarName = 'Research calendar';

AppData _mixedListData(String title) {
  return buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  ).copyWith(
    activeMode: AppMode.general,
    homeWorkspaceNavigationCollapsed: true,
    generalMode: GeneralScheduleData(
      activeScheduleId: 'research',
      selectedDateIso: '2026-06-16',
      defaultView: generalViewList,
      schedules: [
        GeneralSchedule(
          id: 'research',
          name: _calendarName,
          events: [
            for (var index = 0; index < 4; index++)
              GeneralEvent(
                id: 'event-$index',
                calendarId: 'research',
                title: '$title ${index + 1}',
                startDateTimeIso: DateTime(
                  2026,
                  6,
                  16,
                  8 + index,
                ).toIso8601String(),
                endDateTimeIso: DateTime(
                  2026,
                  6,
                  16,
                  9 + index,
                ).toIso8601String(),
                location: index >= 2 ? 'Room A-301' : '',
                recurrenceRule: GeneralEventRecurrenceRule(
                  type: index.isEven
                      ? GeneralEventRecurrence.weekly
                      : GeneralEventRecurrence.none,
                  count: 1,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

Finder _tile(String title) => find.ancestor(
  of: find.text(title),
  matching: find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_GeneralListOccurrenceTile',
  ),
);

RenderParagraph _titleParagraph(WidgetTester tester, String title) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(title), matching: find.byType(RichText)),
    );

Future<void> _setRowWidth(
  WidgetTester tester,
  String title,
  double width,
) async {
  final currentWidth = tester.getSize(_tile(title)).width;
  tester.view.physicalSize = Size(
    tester.view.physicalSize.width + width - currentWidth,
    tester.view.physicalSize.height,
  );
  await tester.pumpAndSettle();
  expect(tester.getSize(_tile(title)).width, closeTo(width, 0.01));
}

void main() {
  for (final (scale, title) in [
    (1.0, '研究生课程设计阶段汇报与答辩安排'),
    (2.0, 'Research programme progress review and defence timetable'),
  ]) {
    testWidgets('mixed list titles stay readable through width changes at '
        '$scale scale', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1300, 1200);
      final app = await workspaceProvider(
        storage: WorkspaceMemoryStorage(_mixedListData(title)),
      );
      try {
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: app,
            textScale: scale,
            home: const GeneralScheduleHomeScreen(),
          ),
        );
        await tester.pumpAndSettle();
        final titles = [
          for (var index = 1; index <= 4; index++) '$title $index',
        ];
        List<double>? previousHeights;
        // Includes the old local 599 -> 600 dp breakpoint and the new
        // content-dependent transitions for optional location metadata.
        for (final width in [599, 600, 640, 680, 720, 760, 800, 1000, 1600]) {
          await _setRowWidth(tester, titles.first, width * scale);
          final paragraphs = [
            for (final value in titles) _titleParagraph(tester, value),
          ];
          for (var index = 0; index < paragraphs.length; index++) {
            expect(
              paragraphs[index].didExceedMaxLines,
              isFalse,
              reason: '${titles[index]} at local width ${width * scale}',
            );
            if (previousHeights != null) {
              expect(
                paragraphs[index].size.height,
                lessThanOrEqualTo(previousHeights[index] + 0.01),
                reason: 'Growing the row must not add title lines.',
              );
            }
          }
          previousHeights = [for (final value in paragraphs) value.size.height];
          final titleRects = [
            for (final value in titles) tester.getRect(find.text(value)),
          ];
          for (var index = 1; index < titleRects.length; index++) {
            expect(
              titleRects[index].left,
              closeTo(titleRects.first.left, 0.01),
            );
            expect(
              titleRects[index].top,
              greaterThan(titleRects[index - 1].top),
            );
          }
          expect(tester.takeException(), isNull);
        }

        // At a wide size all rows have room for metadata alongside the title.
        // Empty locations must return that space to the title, while calendar
        // columns stay aligned for both repeating and ordinary events.
        final calendarRects = [
          for (final value in titles)
            tester.getRect(
              find.descendant(
                of: _tile(value),
                matching: find.text(_calendarName),
              ),
            ),
        ];
        for (final rect in calendarRects.skip(1)) {
          expect(rect.left, closeTo(calendarRects.first.left, 0.01));
          expect(rect.right, closeTo(calendarRects.first.right, 0.01));
        }
        for (final value in titles.take(2)) {
          expect(
            find.descendant(of: _tile(value), matching: find.text('')),
            findsNothing,
          );
        }
        expect(
          _titleParagraph(tester, titles.first).size.width,
          greaterThan(_titleParagraph(tester, titles[2]).size.width),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        app.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
