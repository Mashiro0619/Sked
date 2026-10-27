import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

import '../support/workspace_harness.dart';

final _card = find.byKey(
  const ValueKey('general-timed-occurrence-words-2026-06-15T08:00:00.000'),
);

Future<RenderParagraph> _mount(
  WidgetTester tester,
  String title, {
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 900);
  final data = buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en')
      .copyWith(
        activeMode: AppMode.general,
        homeWorkspaceNavigationCollapsed: true,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'calendar',
          schedules: [
            GeneralSchedule(
              id: 'calendar',
              name: 'Calendar',
              events: [
                GeneralEvent(
                  id: 'words',
                  calendarId: 'calendar',
                  title: title,
                  location: 'Room 101',
                  startDateTimeIso: '2026-06-15T08:00:00.000',
                  endDateTimeIso: '2026-06-15T12:00:00.000',
                ),
              ],
            ),
          ],
          defaultView: generalViewWeek,
          selectedDateIso: '2026-06-15',
          dayStartHour: 8,
          dayEndHour: 13,
          timeGridHourHeight: 100,
          fitWeekColumnsToWidth: true,
        ),
      );
  final app = await workspaceProvider(storage: WorkspaceMemoryStorage(data));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    app.dispose();
    tester.view.reset();
  });
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: app,
      home: const GeneralScheduleHomeScreen(),
      fontFamily: 'Ahem',
      textScale: scale,
      textDirection: direction,
    ),
  );
  await tester.pumpAndSettle();
  final text = find.descendant(of: _card, matching: find.text(title));
  expect(text, findsOneWidget);
  return tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
}

Set<double> _lines(RenderParagraph paragraph, int start, int end) => paragraph
    .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))
    .where((box) => box.right > box.left && box.bottom > box.top)
    .map((box) => box.top)
    .toSet();

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'timeline oversized word stays on one painted line at $scale $direction',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              const title = 'Electromagnetism';
              final paragraph = await _mount(
                tester,
                title,
                scale: scale,
                direction: direction,
              );
              expect(paragraph.text.toPlainText(), title);
              // At 2x scale the narrow column can hold only the ellipsis.
              // Any visible source glyphs must stay on the first line.
              expect(
                _lines(paragraph, 0, title.length).length,
                lessThanOrEqualTo(1),
              );
              expect(paragraph.maxLines, 1);
              expect(paragraph.didExceedMaxLines, isTrue);
              expect(paragraph.overflow, TextOverflow.ellipsis);
              expect(paragraph.textScaler.scale(14), scale * 14);
              expect(
                find.bySemanticsLabel(RegExp(RegExp.escape(title))),
                findsWidgets,
              );
              final titleRect = MatrixUtils.transformRect(
                paragraph.getTransformTo(null),
                paragraph.paintBounds,
              );
              final cardRect = tester.getRect(_card);
              expect(titleRect.top, greaterThanOrEqualTo(cardRect.top));
              expect(titleRect.bottom, lessThanOrEqualTo(cardRect.bottom));
              await tester.tap(_card);
              await tester.pumpAndSettle();
              final detail = find.byType(GeneralEventDetailsSheet);
              expect(detail, findsOneWidget);
              expect(
                find.descendant(of: detail, matching: find.text(title)),
                findsWidgets,
              );
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }

  testWidgets('short words still wrap at spaces', (tester) async {
    const title = 'Go Do It';
    final paragraph = await _mount(tester, title);
    for (final word in ['Go', 'Do', 'It']) {
      final start = title.indexOf(word);
      expect(_lines(paragraph, start, start + word.length), hasLength(1));
    }
    expect(_lines(paragraph, 0, title.length).length, greaterThan(1));
    expect(paragraph.text.toPlainText(), title);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('explicit newline stays before an ellipsized long word', (
    tester,
  ) async {
    const title = 'Go\nElectromagnetism';
    final paragraph = await _mount(tester, title);
    final first = _lines(paragraph, 0, 2);
    final second = _lines(paragraph, 3, title.length);
    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(second.single, greaterThan(first.single));
    expect(paragraph.text.toPlainText(), title);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('CJK title retains ordinary multi-line layout', (tester) async {
    const title = '课程与学习安排';
    final paragraph = await _mount(tester, title);
    expect(_lines(paragraph, 0, title.length).length, greaterThan(1));
    expect(paragraph.text.toPlainText(), title);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
