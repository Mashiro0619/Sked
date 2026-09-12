import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_date_picker.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _popup => find.byKey(const ValueKey('sked-date-picker-content'));
Finder get _sidebar => _key('general-resource-date-picker');
Finder _in(Finder parent, String key) =>
    find.descendant(of: parent, matching: _key(key));
void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _view(WidgetTester tester, String label) async {
  await tester.tap(_key('general-view-switcher'));
  await tester.pumpAndSettle();
  final item = find.widgetWithText(CheckedPopupMenuItem<String>, label);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'week navigator preserves clicked day through day/month/list switches',
    (tester) async {
      _size(tester, const Size(1440, 900));
      final p = await workspaceProvider(mode: AppMode.general, locale: 'zh');
      addTearDown(p.dispose);
      await p.setSelectedGeneralDate(DateTime(2026, 9, 10));
      await p.updateGeneralDisplaySettings(
        dateLabelFormat: generalDateLabelFormatLocalized,
      );
      await tester.pumpWidget(
        WorkspaceHarness(provider: p, locale: const Locale('zh')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('general-date-picker'),
          matching: find.text('2026年9月7日–13日'),
        ),
        findsOneWidget,
      );
      await tester.tap(_key('general-date-picker'));
      await tester.pumpAndSettle();
      final picker = tester.widget<SkedDatePicker>(_popup);
      expect(picker.selectionUnit, DateSelectionUnit.week);
      expect(picker.commitMode, DatePickerCommitMode.immediate);
      await tester.tap(_in(_popup, 'sked-date-2026-09-09'));
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      expect(p.customGeneralDateRange, isNull);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 9));
      final l = AppLocalizations.of(
        tester.element(_key('general-date-picker')),
      );
      await _view(tester, l.viewDay);
      expect(
        find.descendant(
          of: _key('general-date-picker'),
          matching: find.text('2026年9月9日'),
        ),
        findsOneWidget,
      );
      await _view(tester, l.viewList);
      expect(
        find.descendant(
          of: _key('general-date-picker'),
          matching: find.text('2026年9月9日'),
        ),
        findsOneWidget,
      );
      await _view(tester, l.viewMonth);
      await tester.tap(_key('general-date-picker'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SkedDatePicker>(_popup).selectionUnit,
        DateSelectionUnit.month,
      );
      await tester.tap(_in(_popup, 'sked-date-month-2026-10'));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 10, 9));
      expect(
        find.descendant(
          of: _key('general-date-picker'),
          matching: find.text('2026年10月'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'sidebar keeps its browsing month through visibility, collapse and window resize',
    (tester) async {
      _size(tester, const Size(1440, 900));
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      await p.setSelectedGeneralDate(DateTime(2026, 9, 10));
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final canvas = tester.element(_key('workspace-canvas'));
      await tester.tap(_key('general-resource-next-month'));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 9, 10));
      expect(
        find.descendant(of: _sidebar, matching: find.text('October 2026')),
        findsOneWidget,
      );
      await tester.tap(
        _key('resource-calendar-${p.generalSchedules.first.id}'),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _sidebar, matching: find.text('October 2026')),
        findsOneWidget,
      );
      await p.updateHomeWorkspaceNavigationCollapsed(true);
      await tester.pumpAndSettle();
      await p.updateHomeWorkspaceNavigationCollapsed(false);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _sidebar, matching: find.text('October 2026')),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(800, 1100);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _sidebar, matching: find.text('October 2026')),
        findsOneWidget,
      );
      expect(tester.element(_key('workspace-canvas')), same(canvas));
      await tester.tap(_in(_sidebar, 'sked-date-2026-10-13'));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 10, 13));
      expect(p.customGeneralDateRange, isNull);
      for (final day in ['12', '13', '14', '15', '16', '17', '18']) {
        expect(
          tester
              .getSemantics(_in(_sidebar, 'sked-date-2026-10-$day'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
      }
      await tester.tap(_key('general-previous-period'));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 10, 6));
      await tester.tap(_key('general-resource-previous-month'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _sidebar, matching: find.text('September 2026')),
        findsOneWidget,
      );
      await tester.tap(_key('general-date-picker'));
      await tester.pumpAndSettle();
      await tester.tap(_in(_popup, 'sked-date-2026-10-06'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _sidebar, matching: find.text('October 2026')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'range navigation includes weekends without changing month visibility rules',
    (tester) async {
      _size(tester, const Size(1440, 900));
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      await p.setSelectedGeneralDate(DateTime(2026, 9, 11));
      await p.updateGeneralDisplaySettings(showWeekends: false);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final workspaceL10n = AppLocalizations.of(
        tester.element(_key('general-date-picker')),
      );
      await _view(tester, workspaceL10n.dateRangeCustom);
      await tester.pumpAndSettle();
      final saturday = tester.getSemantics(_in(_popup, 'sked-date-2026-09-12'));
      expect(saturday.flagsCollection.isEnabled, Tristate.isTrue);
      await tester.tap(_in(_popup, 'sked-date-2026-09-12'));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 9, 11));
      await tester.tap(_in(_popup, 'sked-date-2026-09-13'));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 9, 12));
      expect(p.customGeneralDateRange!.dayCount, 2);
      expect(p.generalShowWeekends, isFalse);
      final l = AppLocalizations.of(
        tester.element(_key('general-date-picker')),
      );
      await _view(tester, l.viewMonth);
      await p.setSelectedGeneralDate(DateTime(2026, 7, 31));
      await tester.pumpAndSettle();
      await tester.tap(_key('general-date-picker'));
      await tester.pumpAndSettle();
      await tester.tap(_in(_popup, 'sked-date-month-2026-5'));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 5, 29));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop date labels honor saved formats without changing preference values',
    (tester) async {
      _size(tester, const Size(1440, 900));
      final p = await workspaceProvider(mode: AppMode.general, locale: 'zh');
      addTearDown(p.dispose);
      await p.setSelectedGeneralDate(DateTime(2027, 1, 1));
      await tester.pumpWidget(
        WorkspaceHarness(provider: p, locale: const Locale('zh')),
      );
      await tester.pumpAndSettle();
      for (final (format, expected) in [
        (generalDateLabelFormatLocalized, '2026年12月28日–2027年1月3日'),
        (generalDateLabelFormatSlash, '2026/12/28–2027/1/3'),
        (generalDateLabelFormatIso, '2026-12-28–2027-01-03'),
      ]) {
        await p.updateGeneralDisplaySettings(dateLabelFormat: format);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _key('general-date-picker'),
            matching: find.text(expected),
          ),
          findsOneWidget,
        );
        expect(p.generalDateLabelFormat, format);
      }
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'event draft survives date picker cancel and rotation; confirmation only changes draft',
    (tester) async {
      _size(tester, const Size(1280, 900));
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      await p.setSelectedGeneralDate(DateTime(2026, 9, 10));
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(_key('general-workspace-toolbar')),
      );
      await tester.tap(
        _key('general-add-event').evaluate().isNotEmpty
            ? _key('general-add-event')
            : find.byTooltip(l.addEvent).first,
      );
      await tester.pumpAndSettle();
      final editor = find.byType(GeneralEventEditorSheet);
      final state = tester.state(editor);
      await tester.enterText(
        find.descendant(of: editor, matching: find.byType(TextFormField)).first,
        'Date draft',
      );
      final dateButton = find
          .descendant(of: editor, matching: find.byTooltip(l.pickDate))
          .first;
      await tester.ensureVisible(dateButton);
      await tester.tap(dateButton);
      await tester.pumpAndSettle();
      await tester.tap(_in(_popup, 'sked-date-2026-09-14'));
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpAndSettle();
      await tester.tap(_in(_popup, 'sked-date-cancel'));
      await tester.pumpAndSettle();
      expect(tester.state(editor), same(state));
      expect(find.textContaining('2026-09-10'), findsWidgets);
      await tester.ensureVisible(dateButton);
      await tester.tap(dateButton);
      await tester.pumpAndSettle();
      await tester.tap(_in(_popup, 'sked-date-2026-09-14'));
      await tester.tap(_in(_popup, 'sked-date-confirm'));
      await tester.pumpAndSettle();
      expect(tester.state(editor), same(state));
      expect(find.textContaining('2026-09-14'), findsWidgets);
      expect(
        p.generalSchedules
            .expand((c) => c.events)
            .where((e) => e.title == 'Date draft'),
        isEmpty,
      );
      expect(find.text('Date draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );
}
