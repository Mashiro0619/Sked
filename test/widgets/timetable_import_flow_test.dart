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
import 'package:sked/services/data_transfer_codec.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';

import '../support/data_transfer_codec.dart';

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

Future<TimetableProvider> _createProvider({
  DataTransferCodec codec = inlineDataTransferCodec,
}) async {
  final periodTimes = buildDefaultPeriodTimes();
  final provider = TimetableProvider(
    dataTransferCodec: codec,
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

class _PendingTimetableCodec extends DataTransferCodec {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<TimetableImportCandidate> decodeTimetables(
    String source, {
    required String localeCode,
  }) async {
    started.complete();
    await release.future;
    return inlineDataTransferCodec.decodeTimetables(
      source,
      localeCode: localeCode,
    );
  }
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
  String withoutPeriodTimes(TimetableProvider provider) =>
      encodeTimetableDataEnvelope(
        TimetableExportData(
          timetables: [
            provider.activeTimetable.copyWith(
              id: 'incoming',
              config: provider.activeTimetable.config.copyWith(
                name: 'Imported',
              ),
            ),
          ],
          periodTimeSets: const [],
        ),
      );

  testWidgets(
    'late parsing cannot open choices in a replacement data session',
    (tester) async {
      final codec = _PendingTimetableCodec();
      final provider = await _createProvider(codec: codec);
      addTearDown(provider.dispose);
      await _pumpImportButton(
        tester,
        provider,
        source: withoutPeriodTimes(provider),
      );
      final l10n = AppLocalizations.of(tester.element(find.text('Import')));
      await tester.tap(find.text('Import'));
      await tester.pump();
      expect(codec.started.isCompleted, isTrue);
      final reservation = provider.maintenance.reserve();
      provider.maintenance.release(reservation);
      codec.release.complete();
      await tester.pumpAndSettle();
      expect(find.text(l10n.importTimetableDialogTitle), findsNothing);
      expect(find.text(l10n.importFailedCheckContent), findsNothing);
      expect(provider.studentView.timetables.single.config.name, 'Flow test');
    },
  );

  testWidgets(
    'missing bundled times require an explicit choice and cancel cleanly',
    (tester) async {
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      final before = provider.appData.toJson();
      final existingSet = provider.periodTimeSets.single.id;
      await _pumpImportButton(
        tester,
        provider,
        source: withoutPeriodTimes(provider),
      );
      final l10n = AppLocalizations.of(tester.element(find.text('Import')));

      Future<void> openChoice() async {
        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(TextButton, l10n.importAsNewTimetable),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PeriodTimeSetPickerDialogView), findsOneWidget);
      }

      await openChoice();
      expect(provider.appData.toJson(), before);
      tester
          .widget<PeriodTimeSetPickerDialogView>(
            find.byType(PeriodTimeSetPickerDialogView),
          )
          .onCancel();
      await tester.pumpAndSettle();
      expect(provider.appData.toJson(), before);
      await openChoice();
      tester
          .widget<PeriodTimeSetPickerDialogView>(
            find.byType(PeriodTimeSetPickerDialogView),
          )
          .onSelect(existingSet);
      await tester.pumpAndSettle();
      expect(provider.timetables, hasLength(2));
      expect(provider.periodTimeSets, hasLength(1));
      expect(provider.activeTimetable.config.periodTimeSetId, existingSet);
      expect(provider.activeTimetable.config.name, 'Imported');
    },
  );

  testWidgets('JSON replacement displays and retains the original target', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final original = provider.activeTimetable;
    await provider.addTimetable(
      original.config.copyWith(name: 'Other timetable'),
    );
    final other = provider.activeTimetable;
    await provider.switchTimetable(original.id);
    await _pumpImportButton(
      tester,
      provider,
      source: withoutPeriodTimes(provider),
    );
    final l10n = AppLocalizations.of(tester.element(find.text('Import')));
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.chooseTimetableImportMethod(original.config.name)),
      findsOneWidget,
    );
    await provider.switchTimetable(other.id);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.replaceCurrentTimetable),
    );
    await tester.pumpAndSettle();
    tester
        .widget<PeriodTimeSetPickerDialogView>(
          find.byType(PeriodTimeSetPickerDialogView),
        )
        .onSelect(original.config.periodTimeSetId);
    await tester.pumpAndSettle();
    expect(provider.timetables, hasLength(2));
    expect(
      provider.timetables
          .singleWhere((table) => table.id == original.id)
          .config
          .name,
      'Imported',
    );
    expect(
      provider.timetables.singleWhere((table) => table.id == other.id).toJson(),
      other.toJson(),
    );
    expect(provider.periodTimeSets, hasLength(1));
  });

  testWidgets(
    'deleting a confirmed replacement target never overwrites another table',
    (tester) async {
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      final original = provider.activeTimetable;
      await provider.addTimetable(
        original.config.copyWith(name: 'Keep this table'),
      );
      final other = provider.activeTimetable;
      await provider.switchTimetable(original.id);
      await _pumpImportButton(
        tester,
        provider,
        source: withoutPeriodTimes(provider),
      );
      final l10n = AppLocalizations.of(tester.element(find.text('Import')));
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.replaceCurrentTimetable),
      );
      await tester.pumpAndSettle();
      await provider.deleteTimetable(original.id);
      await tester.pumpAndSettle();
      tester
          .widget<PeriodTimeSetPickerDialogView>(
            find.byType(PeriodTimeSetPickerDialogView),
          )
          .onSelect(other.config.periodTimeSetId);
      await tester.pumpAndSettle();
      expect(provider.timetables.single.toJson(), other.toJson());
      expect(provider.periodTimeSets, hasLength(1));
      expect(find.text(l10n.noActiveTimetableToReplaceMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
