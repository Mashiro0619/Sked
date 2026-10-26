import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

Future<AppRuntime> _mount(
  WidgetTester tester, {
  Size size = const Size(1366, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  );
  final provider = await workspaceProvider(
    storage: WorkspaceMemoryStorage(
      initial.copyWith(
        studentMode: initial.studentMode.copyWith(
          activeTimetableId: 'entry-first',
          timetables: [
            for (final (id, name) in [
              ('entry-first', 'First semester'),
              ('entry-second', 'Second semester'),
            ])
              TimetableData(
                id: id,
                config: TimetableConfig(
                  name: name,
                  startDate: DateTime(2026, 10, 5),
                  totalWeeks: 18,
                  periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
                ),
                courses: const [],
              ),
          ],
        ),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    provider.dispose();
  });
  await tester.pumpWidget(WorkspaceHarness(provider: provider));
  await tester.pumpAndSettle();
  return provider;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(_key('workspace-canvas')));

void _expectStaticResourceHeading(WidgetTester tester) {
  final semantics = tester.ensureSemantics();
  try {
    final panel = _key('workspace-resource-panel').hitTestable();
    final heading = find.descendant(
      of: panel,
      matching: find.text(_l10n(tester).timetable),
    );
    expect(heading, findsOneWidget);
    expect(_key('workspace-resource-heading-icon'), findsOneWidget);
    expect(_key('workspace-resource-open'), findsNothing);
    expect(
      find.ancestor(of: heading, matching: find.byType(IconButton)),
      findsNothing,
    );
    final data = tester.getSemantics(heading).getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(data.flagsCollection.isButton, isFalse);
    expect(_key('timetable-picker-heading'), findsNothing);
  } finally {
    semantics.dispose();
  }
}

void main() {
  testWidgets(
    'expanded student resource heading has no duplicate timetable picker',
    (tester) async {
      await _mount(tester);
      expect(
        WorkspaceCanvasScope.maybeOf(tester.element(_key('workspace-canvas')))!
            .resourcePresentation,
        WorkspaceResourcePresentation.expanded,
      );
      _expectStaticResourceHeading(tester);
      expect(_key('student-timetable-picker-button'), findsNothing);

      await tester.tapAt(
        tester.getCenter(_key('workspace-resource-heading-icon')),
      );
      await tester.pumpAndSettle();
      _expectStaticResourceHeading(tester);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'expanded student sidebar keeps direct timetable switching create and edit',
    (tester) async {
      final provider = await _mount(tester);
      final l10n = _l10n(tester);
      await tester.tap(_key('resource-timetable-entry-second'));
      await tester.pumpAndSettle();
      expect(provider.studentView.activeTimetable.id, 'entry-second');
      expect(_key('timetable-picker-heading'), findsNothing);

      final create = find.byTooltip(l10n.createTimetable).hitTestable();
      expect(create, findsOneWidget);
      await tester.tap(create);
      await tester.pumpAndSettle();
      final editor = find.byType(TimetableInformationDialogSurface);
      expect(editor, findsOneWidget);
      expect(
        tester.widget<TimetableInformationDialogSurface>(editor).title,
        isA<Text>().having((text) => text.data, 'title', l10n.createTimetable),
      );
      await tester.tap(
        find.descendant(of: editor, matching: find.text(l10n.cancel)).last,
      );
      await tester.pumpAndSettle();
      expect(editor, findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(_key('resource-timetable-entry-second')),
      );
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      final edit = _key('resource-timetable-edit-entry-second').hitTestable();
      expect(edit, findsOneWidget);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(editor, findsOneWidget);
      expect(
        tester.widget<TimetableInformationDialogSurface>(editor).title,
        isA<Text>().having((text) => text.data, 'title', l10n.editTimetable),
      );
      expect(
        tester
            .widget<TextField>(
              find
                  .descendant(of: editor, matching: find.byType(TextField))
                  .first,
            )
            .controller!
            .text,
        'Second semester',
      );
      expect(_key('timetable-picker-heading'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'collapsed student rail keeps its timetable picker at the heading icon',
    (tester) async {
      await _mount(tester);
      final heading = tester.getRect(_key('workspace-resource-heading-icon'));
      await tester.tap(_key('workspace-resource-collapse'));
      await tester.pumpAndSettle();
      final picker = _key('workspace-resource-open').hitTestable();
      expect(picker, findsOneWidget);
      expect(_key('workspace-resource-heading-icon'), findsNothing);
      expect(tester.getRect(picker), heading);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(_key('timetable-picker-heading'), findsOneWidget);
      expect(_key('timetable-picker-item-entry-first'), findsOneWidget);
      expect(_key('timetable-picker-item-entry-second'), findsOneWidget);
      expect(_key('timetable-picker-create'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'student resource drawer keeps its heading static while its list is visible',
    (tester) async {
      final provider = await _mount(tester, size: const Size(1000, 900));
      await tester.tap(_key('workspace-resource-collapse'));
      await tester.pumpAndSettle();
      expect(_key('workspace-resource-scrim'), findsOneWidget);
      _expectStaticResourceHeading(tester);
      expect(
        find.byTooltip(_l10n(tester).createTimetable).hitTestable(),
        findsOneWidget,
      );

      await tester.tapAt(
        tester.getCenter(_key('workspace-resource-heading-icon')),
      );
      await tester.pumpAndSettle();
      expect(_key('workspace-resource-scrim'), findsOneWidget);
      _expectStaticResourceHeading(tester);
      await tester.tap(_key('resource-timetable-entry-second'));
      await tester.pumpAndSettle();
      expect(provider.studentView.activeTimetable.id, 'entry-second');
      expect(_key('workspace-resource-scrim'), findsNothing);
      expect(_key('workspace-resource-open').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'phone timetable title still opens the picker with switch create and edit',
    (tester) async {
      final provider = await _mount(tester, size: const Size(390, 844));
      final picker = _key('student-timetable-picker-button').hitTestable();
      expect(picker, findsOneWidget);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(_key('timetable-picker-heading'), findsOneWidget);
      expect(_key('timetable-picker-create'), findsOneWidget);
      expect(_key('timetable-picker-edit-entry-first'), findsOneWidget);
      await tester.tap(_key('timetable-picker-item-entry-second'));
      await tester.pumpAndSettle();
      expect(provider.studentView.activeTimetable.id, 'entry-second');
      expect(_key('timetable-picker-heading'), findsNothing);
      expect(picker, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
