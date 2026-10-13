import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/main.dart' show MyApp;
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_task_body.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Future<void> _sendPlatformTarget(
  WidgetTester tester,
  Map<String, Object?> target,
) async {
  const codec = StandardMethodCodec();
  final acknowledged = Completer<void>();
  // This is the same incoming platform channel used by notification/widget
  // launches. It reaches MyApp's real root routes without a workspace scope.
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    AndroidProductivityChannel.name,
    codec.encodeMethodCall(
      MethodCall(
        AndroidProductivityChannel.agendaIntentEvent,
        jsonEncode(target),
      ),
    ),
    (_) => acknowledged.complete(),
  );
  await acknowledged.future;
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in AppMode.values) {
    for (final size in [const Size(393, 852), const Size(1280, 1000)]) {
      testWidgets(
        '$mode platform target opens its shared details and editor at $size',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          const bridge = MethodChannel(AndroidProductivityChannel.name);
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            bridge,
            (_) async => null,
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              bridge,
              null,
            );
          });
          final provider = await workspaceProvider(
            storage: WorkspaceMemoryStorage(mobileLayoutData(locale: 'en')),
          );
          final layouts = DesktopLayoutPreferences.memory();
          addTearDown(provider.dispose);
          addTearDown(layouts.dispose);
          await provider.acceptPrivacyPolicyCurrentVersion();
          await tester.pumpWidget(
            MyApp(provider: provider, desktopLayoutPreferences: layouts),
          );
          await tester.pumpAndSettle();
          try {
            final table = provider.activeTimetable;
            final course = table.courses.first;
            final calendar = provider.generalSchedules.first;
            final event = calendar.events.firstWhere(
              (item) => item.id == 'mobile-day-21',
            );
            final occurrence = provider
                .generalOccurrencesForRange(
                  startInclusive: DateTime(2026, 9, 21),
                  endExclusive: DateTime(2026, 9, 22),
                )
                .firstWhere((item) => item.event.id == event.id);
            final courseDate = addCalendarDays(
              startOfWeekFor(table.config, course.semesterWeeks.first),
              course.dayOfWeek - 1,
            );
            final target = mode == AppMode.student
                ? <String, Object?>{
                    'sourceType': AgendaSourceType.course,
                    'timetableId': table.id,
                    'courseId': course.id,
                    'dateIso': courseDate.toIso8601String(),
                  }
                : <String, Object?>{
                    'sourceType': AgendaSourceType.generalEvent,
                    'calendarId': calendar.id,
                    'eventId': event.id,
                    'dateIso': event.startDateTimeIso,
                    'occurrenceKey': occurrence.occurrenceKey,
                  };
            await _sendPlatformTarget(tester, target);
            final details = find.byType(
              mode == AppMode.student
                  ? CourseDetailsSheet
                  : GeneralEventDetailsSheet,
            );
            expect(details, findsOneWidget);
            expect(
              find.descendant(of: details, matching: find.byType(SkedTaskBody)),
              findsOneWidget,
            );
            final l = AppLocalizations.of(tester.element(details));
            final edit = find.descendant(
              of: details,
              matching: find.byTooltip(
                mode == AppMode.student ? l.editCourseTooltip : l.editEvent,
              ),
            );
            await tester.ensureVisible(edit);
            await tester.tap(edit);
            await tester.pumpAndSettle();

            final editor = find.byType(
              mode == AppMode.student
                  ? CourseEditorSheet
                  : GeneralEventEditorSheet,
            );
            expect(editor, findsOneWidget);
            expect(
              WorkspaceEditorScope.maybeOf(tester.element(editor)),
              isNull,
            );
            final shell = find.descendant(
              of: editor,
              matching: find.byType(AppSheetScaffold),
            );
            expect(shell, findsOneWidget);
            expect(
              tester.widget<AppSheetScaffold>(shell).editorActions,
              isNotNull,
            );
            expect(
              find.descendant(
                of: editor,
                matching: find.byKey(const ValueKey('app-sheet-header')),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: editor,
                matching: find.byType(SkedEditorTextField),
              ),
              findsWidgets,
            );
            final input = find
                .descendant(of: editor, matching: find.byType(TextField))
                .first;
            final name = mode == AppMode.student ? course.name : event.title;
            expect(tester.widget<TextField>(input).controller!.text, name);
            await tester.enterText(input, 'A platform-launched draft');
            await tester.tap(
              find.descendant(of: editor, matching: find.text(l.cancel)),
            );
            await tester.pumpAndSettle();
            expect(find.text(l.unsavedChangesMessage), findsOneWidget);
            await tester.tap(find.text(l.discardChangesAndExit));
            await tester.pumpAndSettle();
            expect(editor, findsNothing);
            expect(
              mode == AppMode.student
                  ? provider.timetables
                        .firstWhere((item) => item.id == table.id)
                        .courses
                        .firstWhere((item) => item.id == course.id)
                        .name
                  : provider.generalSchedules
                        .firstWhere((item) => item.id == calendar.id)
                        .events
                        .firstWhere((item) => item.id == event.id)
                        .title,
              name,
            );
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
