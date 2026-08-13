import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/course_details_sheet.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://course-details-test';
}

CourseItem _course({required String id, required String name}) {
  return CourseItem(
    id: id,
    name: name,
    teacher: '',
    location: 'Room 101',
    dayOfWeek: 1,
    semesterWeeks: const [1],
    periods: const [1, 2],
    startMinutes: 8 * 60,
    endMinutes: 9 * 60 + 40,
    timeRange: buildTimeRange(8 * 60, 9 * 60 + 40),
    credit: 0,
    remarks: '',
    customFields: const {},
  );
}

Future<TimetableProvider> _createProvider({
  String courseAName = 'Course A',
  String courseBName = 'Course B',
}) async {
  final periodTimes = buildDefaultPeriodTimes();
  final timetable = TimetableData(
    id: 'table-1',
    config: TimetableConfig(
      name: 'Test timetable',
      startDate: DateTime(2026, 5, 25),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: [
      _course(id: 'course-a', name: courseAName),
      _course(id: 'course-b', name: courseBName),
    ],
  );
  final data = buildInitialAppData(periodTimes, localeCode: defaultLocaleCode)
      .copyWith(
        activeMode: AppMode.student,
        studentMode: StudentModeData(
          activeTimetableId: timetable.id,
          timetables: [timetable],
          periodTimeSets: [
            PeriodTimeSet(
              id: defaultPeriodTimeSetId,
              name: 'Default',
              periodTimes: periodTimes,
            ),
          ],
        ),
      );
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(data),
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.load();
  return provider;
}

void main() {
  testWidgets('conflict course cards fit compact phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider(
      courseAName: 'Advanced interaction design and scheduling studio',
      courseBName: 'Very long overlapping laboratory practicum section',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CourseDetailsSheet(
              courseId: 'course-a',
              weekday: 1,
              conflictKey: null,
              isFullConflict: true,
              onEdit: () {},
              onSelectDisplayedCourse: (_) {},
              onEditConflictCourse: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CourseDetailsSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflict action buttons ignore rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider();
    final actionCompleter = Completer<void>();
    var selectCount = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CourseDetailsSheet(
              courseId: 'course-a',
              weekday: 1,
              conflictKey: null,
              isFullConflict: true,
              onEdit: () {},
              onSelectDisplayedCourse: (_) {
                selectCount += 1;
                return actionCompleter.future;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final setDisplayedButton = find.widgetWithIcon(
      IconButton,
      Icons.visibility_outlined,
    );
    expect(setDisplayedButton, findsOneWidget);

    await tester.tap(setDisplayedButton);
    await tester.tap(setDisplayedButton, warnIfMissed: false);

    expect(selectCount, 1);

    await tester.pump();
    expect(tester.widget<IconButton>(setDisplayedButton).onPressed, isNull);

    actionCompleter.complete();
    await tester.pump();

    expect(selectCount, 1);
  });

  testWidgets(
    'pending conflict action announces progress and blocks dismissal',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final provider = await _createProvider();
      final actionStarted = Completer<void>();
      final allowAction = Completer<void>();

      await tester.pumpWidget(
        ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    unawaited(
                      showAppModalSheet<void>(
                        context: context,
                        enableDrag: false,
                        builder: (sheetContext) => CourseDetailsSheet(
                          courseId: 'course-a',
                          weekday: 1,
                          conflictKey: null,
                          isFullConflict: true,
                          onEdit: () {},
                          onSelectDisplayedCourse: (_) async {
                            actionStarted.complete();
                            await allowAction.future;
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open course details'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open course details'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.visibility_outlined),
      );
      await actionStarted.future;
      await tester.pump();

      final busyIndicator = find.byKey(
        const ValueKey('course-details-busy-indicator'),
      );
      expect(
        find.descendant(
          of: busyIndicator,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );
      final savingSemantics = find.byKey(
        const ValueKey('course-details-busy-semantics'),
      );
      expect(savingSemantics, findsOneWidget);
      expect(
        tester.getSemantics(savingSemantics),
        matchesSemantics(label: 'Saving changes...', isLiveRegion: true),
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();

      expect(find.byType(CourseDetailsSheet), findsOneWidget);

      allowAction.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CourseDetailsSheet), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('failed conflict action shows feedback and allows retry', (
    tester,
  ) async {
    final provider = await _createProvider();
    var failAction = true;
    var selectCount = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CourseDetailsSheet(
              courseId: 'course-a',
              weekday: 1,
              conflictKey: null,
              isFullConflict: true,
              onEdit: () {},
              onSelectDisplayedCourse: (_) async {
                selectCount += 1;
                if (failAction) {
                  throw StateError('display selection failed');
                }
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final setDisplayedButton = find.widgetWithIcon(
      IconButton,
      Icons.visibility_outlined,
    );
    await tester.tap(setDisplayedButton);
    await tester.pumpAndSettle();

    expect(selectCount, 1);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.widget<IconButton>(setDisplayedButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    failAction = false;
    await tester.tap(setDisplayedButton);
    await tester.pump();

    expect(selectCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing course only notifies once across rebuilds', (
    tester,
  ) async {
    final provider = await _createProvider();
    StateSetter? refreshHost;
    var missingCount = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              refreshHost = setState;
              return Scaffold(
                body: CourseDetailsSheet(
                  courseId: 'missing-course',
                  weekday: 1,
                  conflictKey: null,
                  isFullConflict: false,
                  onEdit: () {},
                  onMissing: () => missingCount += 1,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pump();
    expect(missingCount, 1);

    refreshHost?.call(() {});
    await tester.pump();
    await tester.pump();

    expect(missingCount, 1);
  });
}
