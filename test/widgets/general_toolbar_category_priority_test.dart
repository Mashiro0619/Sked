import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/sked_date_picker.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));
Finder get categoryText => find.descendant(
  of: key('general-calendar-selector'),
  matching: find.byType(Text),
);
Finder get dateText => find.descendant(
  of: key('general-date-title-button'),
  matching: find.byType(Text),
);

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await super.save(value);
  }
}

Future<(TimetableProvider, _Storage)> home(
  WidgetTester t, {
  double width = 500,
  double scale = 1,
  String name = 'My calendar',
  String view = generalViewWeek,
  GeneralDateRange? range,
  List<String> hidden = const [],
  String format = generalDateLabelFormatSlash,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 900);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  final base = mobileLayoutData();
  final selected =
      range ?? GeneralDateRange(DateTime(2026, 9, 22), DateTime(2026, 9, 24));
  final data = base.copyWith(
    generalMode: base.generalMode.copyWith(
      selectedDateIso: selected.start.toIso8601String().split('T').first,
      defaultView: view,
      dateLabelFormat: format,
      customDateRange: view == generalViewWeek ? selected : null,
      hiddenToolbarNavigationIds: hidden,
      schedules: [
        for (final s in base.generalMode.schedules) s.copyWith(name: name),
      ],
    ),
  );
  final storage = _Storage(data);
  final p = await workspaceProvider(storage: storage, locale: 'zh');
  addTearDown(p.dispose);
  await t.pumpWidget(
    WorkspaceHarness(provider: p, locale: const Locale('zh'), textScale: scale),
  );
  await t.pumpAndSettle();
  return (p, storage);
}

void fullyVisible(WidgetTester t, Finder text) {
  final paragraph = t.renderObject<RenderParagraph>(text);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    paragraph.getMaxIntrinsicWidth(double.infinity),
    lessThanOrEqualTo(paragraph.size.width + .01),
  );
}

void main() {
  testWidgets(
    'mobile custom range gives up its year before truncating the category',
    (t) async {
      final (p, storage) = await home(t);
      final before = storage.writes;
      expect(t.widget<Text>(dateText).data, '9/22–24');
      fullyVisible(t, categoryText);
      fullyVisible(t, dateText);
      final semantics = t
          .widget<Semantics>(
            find
                .ancestor(
                  of: key('general-date-title-button'),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties;
      expect(semantics.label, contains('2026'));
      expect(semantics.label, contains('自定义'));
      expect(semantics.onLongPress, isNotNull);
      expect(p.generalDateLabelFormat, generalDateLabelFormatSlash);
      expect(storage.writes, before);
      await t.tap(key('general-date-title-button'));
      await t.pumpAndSettle();
      expect(find.byType(SkedDatePicker), findsOneWidget);
      await t.tap(key('sked-date-picker-close'));
      await t.pumpAndSettle();
      expect(storage.writes, before);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('mobile full year returns once category and date both fit', (
    t,
  ) async {
    await home(t, width: 590);
    expect(t.widget<Text>(dateText).data, '2026/9/22–24');
    fullyVisible(t, categoryText);
    fullyVisible(t, dateText);
    t.view.physicalSize = const Size(500, 900);
    await t.pumpAndSettle();
    expect(t.widget<Text>(dateText).data, '9/22–24');
    fullyVisible(t, categoryText);
    t.view.physicalSize = const Size(590, 900);
    await t.pumpAndSettle();
    expect(t.widget<Text>(dateText).data, '2026/9/22–24');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final view in [generalViewDay, generalViewList, generalViewMonth]) {
    testWidgets(
      'mobile $view also prioritizes the category over a redundant year',
      (t) async {
        await home(t, width: 500, name: 'My calendar notes', view: view);
        expect(
          t.widget<Text>(dateText).data,
          view == generalViewMonth ? '9月' : '9/22',
        );
        fullyVisible(t, categoryText);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('both month names remain in a same-year boundary range', (
    t,
  ) async {
    await home(
      t,
      width: 590,
      name: 'My calendar notes',
      range: GeneralDateRange(DateTime(2026, 9, 28), DateTime(2026, 10, 4)),
    );
    expect(t.widget<Text>(dateText).data, '9/28–10/4');
    fullyVisible(t, categoryText);
    fullyVisible(t, dateText);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'a range spanning two years never pretends its years are redundant',
    (t) async {
      await home(
        t,
        name: 'My calendar with a very long name',
        range: GeneralDateRange(DateTime(2026, 12, 29), DateTime(2027, 1, 4)),
      );
      final label = t.widget<Text>(dateText).data!;
      expect(label, contains('2026'));
      expect(label, contains('2027'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('a hidden category leaves the full width to the date', (t) async {
    await home(t, width: 360, hidden: ['category']);
    expect(categoryText, findsNothing);
    expect(t.widget<Text>(dateText).data, '2026/9/22–24');
    fullyVisible(t, dateText);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'long category $width/$scale loses the year but keeps all touch controls',
        (t) async {
          final (_, storage) = await home(
            t,
            width: width,
            scale: scale,
            name: '工作、学习与日常生活的完整分类名称',
          );
          final before = storage.writes;
          expect(t.widget<Text>(dateText).data, isNot(contains('2026')));
          final row = t.getRect(key('general-compact-toolbar-single-row'));
          for (final id in [
            'general-calendar-selector',
            'general-date-title-button',
            'general-view-switcher',
            'general-settings-button',
            'general-toolbar-more-button',
          ]) {
            final rect = t.getRect(key(id));
            expect(rect.center.dy, closeTo(row.center.dy, 1));
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
          }
          expect(storage.writes, before);
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
