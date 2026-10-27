import 'dart:async';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/import_count_limits.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/timetable_import_flow.dart';
import 'package:sked/services/data_transfer_codec.dart';
import 'package:sked/services/text_file_picker.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';

import '../support/data_transfer_codec.dart';
import '../support/timetable_storage_fakes.dart';
import '../support/oversized_text_file_picker.dart';

Future<AppRuntime> _createProvider({
  DataTransferCodec codec = inlineDataTransferCodec,
}) async {
  final periodTimes = buildDefaultPeriodTimes();
  final provider = AppRuntime(
    dataTransferCodec: codec,
    storage: WorkspaceMemoryStorage(
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
      path: 'memory://timetable-import-flow-test',
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.lifecycle.load();
  return provider;
}

class _PendingTimetableCodec extends DataTransferCodec {
  _PendingTimetableCodec() : super(run: runDataTransferInline);

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
  AppRuntime provider, {
  String? source,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    AppScope(
      app: provider,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => source == null
                      ? TimetableImportFlow.importTimetables(context)
                      : TimetableImportFlow.importTimetablesFromSource(
                          context,
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
  for (final language in ['en', 'zh']) {
    testWidgets(
      'oversized timetable file uses the selected $language message and keeps data',
      (tester) async {
        final previousPicker = FileSelectorPlatform.instance;
        FileSelectorPlatform.instance = OversizedTextFilePicker();
        addTearDown(() => FileSelectorPlatform.instance = previousPicker);
        final provider = await _createProvider();
        addTearDown(provider.dispose);
        final before = provider.workspaceView.data.toJson();
        await _pumpImportButton(tester, provider, locale: Locale(language));
        final l10n = AppLocalizations.of(tester.element(find.text('Import')));
        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.importTextFileTooLarge(TextFilePicker.maxMegabytes)),
          findsOneWidget,
        );
        expect(provider.workspaceView.data.toJson(), before);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('invalid import content shows the selected UI language', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final before = provider.workspaceView.data.toJson();
    await _pumpImportButton(
      tester,
      provider,
      source: '{broken JSON containing internal details',
      locale: const Locale('zh'),
    );
    final l10n = AppLocalizations.of(tester.element(find.text('Import')));
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.importFailedCheckContent), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('internal details'), findsNothing);
    expect(provider.workspaceView.data.toJson(), before);
  });

  String withoutPeriodTimes(AppRuntime provider) => encodeTimetableDataEnvelope(
    TimetableExportData(
      timetables: [
        provider.studentView.activeTimetable.copyWith(
          id: 'incoming',
          config: provider.studentView.activeTimetable.config.copyWith(
            name: 'Imported',
          ),
        ),
      ],
      periodTimeSets: const [],
    ),
  );

  for (final locale in [
    const Locale('en'),
    const Locale('zh'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'oversized imports retain data and explain the limit: $locale',
      (tester) async {
        final provider = await _createProvider();
        addTearDown(provider.dispose);
        final before = provider.workspaceView.data.toJson();
        final source = ImportExportEnvelope(
          schema: timetableDataSchema,
          version: importExportVersion,
          data: {
            'timetables': List.filled(ImportCountLimits.timetables + 1, null),
            'privateSource': 'do not display imported content',
          },
        ).encode();
        await _pumpImportButton(
          tester,
          provider,
          source: source,
          locale: locale,
        );
        final l10n = AppLocalizations.of(tester.element(find.text('Import')));
        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.importEntryLimitExceededMessage), findsOneWidget);
        expect(find.text(l10n.importFailedCheckContent), findsNothing);
        expect(find.text(l10n.selectTimetablesToImport), findsNothing);
        expect(
          find.textContaining('do not display imported content'),
          findsNothing,
        );
        expect(provider.workspaceView.data.toJson(), before);
      },
    );
  }

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
      final before = provider.workspaceView.data.toJson();
      final existingSet = provider.studentView.periodTimeSets.single.id;
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
      expect(provider.workspaceView.data.toJson(), before);
      tester
          .widget<PeriodTimeSetPickerDialogView>(
            find.byType(PeriodTimeSetPickerDialogView),
          )
          .onCancel();
      await tester.pumpAndSettle();
      expect(provider.workspaceView.data.toJson(), before);
      await openChoice();
      tester
          .widget<PeriodTimeSetPickerDialogView>(
            find.byType(PeriodTimeSetPickerDialogView),
          )
          .onSelect(existingSet);
      await tester.pumpAndSettle();
      expect(provider.studentView.timetables, hasLength(2));
      expect(provider.studentView.periodTimeSets, hasLength(1));
      expect(
        provider.studentView.activeTimetable.config.periodTimeSetId,
        existingSet,
      );
      expect(provider.studentView.activeTimetable.config.name, 'Imported');
    },
  );

  testWidgets('JSON replacement displays and retains the original target', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final original = provider.studentView.activeTimetable;
    await provider.studentCommands.addTimetable(
      original.config.copyWith(name: 'Other timetable'),
    );
    final other = provider.studentView.activeTimetable;
    await provider.studentCommands.switchTimetable(original.id);
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
    await provider.studentCommands.switchTimetable(other.id);
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
    expect(provider.studentView.timetables, hasLength(2));
    expect(
      provider.studentView.timetables
          .singleWhere((table) => table.id == original.id)
          .config
          .name,
      'Imported',
    );
    expect(
      provider.studentView.timetables
          .singleWhere((table) => table.id == other.id)
          .toJson(),
      other.toJson(),
    );
    expect(provider.studentView.periodTimeSets, hasLength(1));
  });

  testWidgets(
    'deleting a confirmed replacement target never overwrites another table',
    (tester) async {
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      final original = provider.studentView.activeTimetable;
      await provider.studentCommands.addTimetable(
        original.config.copyWith(name: 'Keep this table'),
      );
      final other = provider.studentView.activeTimetable;
      await provider.studentCommands.switchTimetable(original.id);
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
      await provider.studentCommands.deleteTimetable(original.id);
      await tester.pumpAndSettle();
      tester
          .widget<PeriodTimeSetPickerDialogView>(
            find.byType(PeriodTimeSetPickerDialogView),
          )
          .onSelect(other.config.periodTimeSetId);
      await tester.pumpAndSettle();
      expect(provider.studentView.timetables.single.toJson(), other.toJson());
      expect(provider.studentView.periodTimeSets, hasLength(1));
      expect(find.text(l10n.importFailedCheckContent), findsOneWidget);
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
      final before = provider.workspaceView.data.toJson();
      await _pumpImportButton(
        tester,
        provider,
        source: encodeTimetableDataEnvelope(
          TimetableExportData(
            timetables: provider.studentView.timetables,
            periodTimeSets: provider.studentView.periodTimeSets,
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
      expect(provider.workspaceView.data.toJson(), before);
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
