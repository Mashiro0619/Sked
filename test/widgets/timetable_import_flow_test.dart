import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/timetable_import_flow.dart';
import 'package:sked/widgets/sked_floating_surface.dart';

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
  Future<String?> filePath() async => 'memory://timetable-import-flow-test';
}

Future<TimetableProvider> _createProvider() async {
  final periodTimes = buildDefaultPeriodTimes();
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(
      buildInitialAppData(periodTimes, localeCode: defaultLocaleCode).copyWith(
        activeMode: AppMode.student,
        studentMode: StudentModeData(
          activeTimetableId: 'table-1',
          timetables: [
            TimetableData(
              id: 'table-1',
              config: TimetableConfig(
                name: 'Flow test',
                startDate: DateTime(2026, 5, 25),
                totalWeeks: 18,
                periodTimeSetId: defaultPeriodTimeSetId,
              ),
              courses: const [],
            ),
          ],
          periodTimeSets: [
            PeriodTimeSet(
              id: defaultPeriodTimeSetId,
              name: 'Default',
              periodTimes: periodTimes,
            ),
          ],
        ),
      ),
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.load();
  return provider;
}

Future<void> _pumpImportButton(
  WidgetTester tester,
  TimetableProvider provider, {
  String? source,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => source == null
                      ? TimetableImportFlow.importTimetables(context, provider)
                      : TimetableImportFlow.importTimetablesFromSource(
                          context,
                          provider,
                          source,
                        ),
                  child: const Text('Import'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'discarding bundled periods anchors the next picker to the closed dialog action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      final before = provider.appData.toJson();
      await _pumpImportButton(
        tester,
        provider,
        source: encodeTimetableDataEnvelope(
          TimetableExportData(
            timetables: provider.timetables,
            periodTimeSets: provider.periodTimeSets,
          ),
        ),
      );
      final l10n = AppLocalizations.of(tester.element(find.text('Import')));
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.importAsNewTimetable),
      );
      await tester.pumpAndSettle();
      final discard = find.widgetWithText(
        TextButton,
        l10n.discardBundledPeriodTimeSets,
      );
      final sourceRect = tester.getRect(discard);
      tester.widget<TextButton>(discard).onPressed!();
      await tester.pumpAndSettle();
      expect(discard, findsNothing);
      final panel = tester.getRect(find.byType(SkedFloatingSurface));
      expect(panel.overlaps(sourceRect), isFalse);
      expect(
        [
          (panel.left - sourceRect.right).abs(),
          (sourceRect.left - panel.right).abs(),
          (panel.top - sourceRect.bottom).abs(),
          (sourceRect.top - panel.bottom).abs(),
        ].reduce((a, b) => a < b ? a : b),
        closeTo(6, 1),
      );
      await tester.binding.setSurfaceSize(const Size(1500, 1000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(SkedFloatingSurface)).topLeft,
        panel.topLeft,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(provider.appData.toJson(), before);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('file import ignores concurrent duplicate calls', (tester) async {
    final provider = await _createProvider();
    const channel = MethodChannel(
      'plugins.flutter.io/file_selector',
      StandardMethodCodec(),
    );
    final pickerStarted = Completer<void>();
    final pickerResult = Completer<List<String>?>();
    var pickCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'openFile') {
            pickCalls += 1;
            if (!pickerStarted.isCompleted) {
              pickerStarted.complete();
            }
            return pickerResult.future;
          }
          return null;
        });
    addTearDown(() {
      if (!pickerResult.isCompleted) {
        pickerResult.complete(null);
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await _pumpImportButton(tester, provider);

    final importButton = find.widgetWithText(FilledButton, 'Import');
    expect(importButton, findsOneWidget);

    await tester.tap(importButton);
    await tester.tap(importButton, warnIfMissed: false);
    await pickerStarted.future;
    await tester.pumpAndSettle();

    expect(pickCalls, 1);

    pickerResult.complete(null);
    await tester.pumpAndSettle();
  });
}
