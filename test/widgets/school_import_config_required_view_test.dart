import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/screens/school_import_parser_settings_page.dart';
import 'package:sked/screens/school_web_import_page.dart';
import 'package:sked/services/text_file_picker.dart';
import 'package:sked/widgets/school_import_config_required_view.dart';

import '../support/data_transfer_codec.dart';
import '../support/timetable_storage_fakes.dart';

const _draft = '<table><tr><td>Monday mathematics</td></tr></table>';
const _site = SchoolSite(
  name: 'Example University',
  loginUrl: 'https://school.example.test/timetable',
);

class _FilePicker extends FileSelectorPlatform {
  _FilePicker(this.pick);

  final Future<XFile?> Function() pick;
  int calls = 0;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) {
    calls += 1;
    expect(acceptedTypeGroups!.single.extensions, ['json']);
    return pick();
  }
}

void _usePicker(_FilePicker picker) {
  final previous = FileSelectorPlatform.instance;
  FileSelectorPlatform.instance = picker;
  addTearDown(() => FileSelectorPlatform.instance = previous);
}

Future<AppRuntime> _createRuntime() async {
  final runtime = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: WorkspaceMemoryStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.student,
        aiApiSettings: const AiApiSettings(
          source: schoolImportParserSourceCustomOpenAi,
          customBaseUrl: 'https://api.example.test/v1',
          customApiKey: 'synthetic-key',
          customModel: '',
        ),
      ),
      path: 'memory://import-guidance-test',
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await runtime.lifecycle.load();
  addTearDown(runtime.dispose);
  return runtime;
}

Future<AppLocalizations> _pumpEntry(
  WidgetTester tester,
  AppRuntime runtime, {
  required bool web,
  Locale locale = const Locale('en'),
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    AppScope(
      app: runtime,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: web
            ? SchoolWebImportPage(
                site: _site,
                loadSites: () async => [_site],
                webViewBuilder: (_) => const Text('Synthetic school page'),
                supportsPopupWindows: false,
              )
            : const SchoolHtmlImportPage(initialContent: _draft),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(
    tester.element(find.byType(SchoolImportConfigRequiredView)),
  );
}

Future<void> _configureAndReturn(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final settings = find.widgetWithText(
    OutlinedButton,
    l10n.schoolImportConfigureAction,
  );
  await tester.ensureVisible(settings);
  await tester.pumpAndSettle();
  await tester.tap(settings);
  await tester.pumpAndSettle();
  expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
  final modelField = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText == l10n.schoolImportParserModel,
  );
  await tester.ensureVisible(modelField);
  await tester.enterText(modelField, 'synthetic-model');
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(SchoolImportConfigRequiredView), findsNothing);
}

void _expectDraft(WidgetTester tester) {
  expect(
    tester.widget<TextField>(find.byType(TextField)).controller!.text,
    _draft,
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; !ready() && frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(ready(), isTrue);
}

XFile _timetableFile(AppRuntime runtime) => XFile.fromData(
  Uint8List.fromList(
    utf8.encode(
      encodeTimetableDataEnvelope(
        TimetableExportData(
          timetables: [
            TimetableData(
              id: 'synthetic-import',
              config: TimetableConfig(
                name: 'Local file timetable',
                startDate: DateTime(2026, 10, 26),
                totalWeeks: 18,
                periodTimeSetId: runtime.studentView.periodTimeSets.first.id,
              ),
              courses: const [],
            ),
          ],
          periodTimeSets: runtime.studentView.periodTimeSets,
        ),
      ),
    ),
  ),
);

void main() {
  for (final web in [false, true]) {
    final entry = web ? 'school webpage' : 'HTML paste';

    for (final locale in [
      const Locale('en'),
      const Locale('zh'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      for (final size in [const Size(320, 640), const Size(1440, 900)]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            '$entry offers reachable local paths before AI at $locale $size $brightness 2x',
            (tester) async {
              await tester.binding.setSurfaceSize(size);
              addTearDown(() => tester.binding.setSurfaceSize(null));
              final runtime = await _createRuntime();
              final picker = _FilePicker(() async => null);
              _usePicker(picker);
              final l10n = await _pumpEntry(
                tester,
                runtime,
                web: web,
                locale: locale,
                scale: 2,
                brightness: brightness,
              );
              final heading = find.text(l10n.schoolImportWithoutApiTitle);
              final manual = find.text(l10n.schoolImportManualHint);
              final file = find.widgetWithText(
                FilledButton,
                l10n.schoolImportFileAction,
              );
              final ai = find.text(l10n.schoolImportAiHint);
              final settings = find.widgetWithText(
                OutlinedButton,
                l10n.schoolImportConfigureAction,
              );
              expect(
                tester.getTopLeft(heading).dy,
                lessThan(tester.getTopLeft(manual).dy),
              );
              expect(
                tester.getTopLeft(manual).dy,
                lessThan(tester.getTopLeft(file).dy),
              );
              expect(
                tester.getTopLeft(file).dy,
                lessThan(tester.getTopLeft(ai).dy),
              );
              expect(
                tester.getTopLeft(ai).dy,
                lessThan(tester.getTopLeft(settings).dy),
              );
              expect(tester.widget<Text>(manual).maxLines, isNull);
              for (final button in [file, settings]) {
                await tester.ensureVisible(button);
                await tester.pumpAndSettle();
                final rect = tester.getRect(button);
                expect(rect.height, greaterThanOrEqualTo(48));
                expect(rect.width, greaterThanOrEqualTo(48));
                expect(rect.left, greaterThanOrEqualTo(24));
                expect(rect.right, lessThanOrEqualTo(size.width - 24));
                expect(button.hitTestable(), findsOneWidget);
              }
              await tester.ensureVisible(file);
              await tester.pumpAndSettle();
              final rect = tester.getRect(file);
              await tester.tapAt(Offset(rect.center.dx, rect.bottom - 3));
              await tester.pumpAndSettle();
              expect(picker.calls, 1);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('$entry returns from parser setup to the retained page', (
      tester,
    ) async {
      final runtime = await _createRuntime();
      final l10n = await _pumpEntry(tester, runtime, web: web);
      await _configureAndReturn(tester, l10n);
      expect(runtime.settingsView.aiApiSettings.customModel, 'synthetic-model');
      if (web) {
        expect(find.text('Synthetic school page'), findsOneWidget);
      } else {
        _expectDraft(tester);
      }
      expect(tester.takeException(), isNull);
    });

    for (final outcome in [
      'cancel',
      'invalid',
      'picker failure',
      'oversized',
    ]) {
      testWidgets('$entry keeps its input and data after file $outcome', (
        tester,
      ) async {
        final runtime = await _createRuntime();
        final before = runtime.workspaceView.data.toJson();
        final picker = _FilePicker(() async {
          return switch (outcome) {
            'cancel' => null,
            'invalid' => XFile.fromData(
              Uint8List.fromList(utf8.encode('invalid JSON')),
            ),
            'oversized' => throw const TextFileTooLargeException(),
            _ => throw StateError('Synthetic picker failure'),
          };
        });
        _usePicker(picker);
        final l10n = await _pumpEntry(tester, runtime, web: web);
        final file = find.widgetWithText(
          FilledButton,
          l10n.schoolImportFileAction,
        );
        await tester.tap(file);
        await tester.pumpAndSettle();
        expect(picker.calls, 1);
        expect(runtime.workspaceView.data.toJson(), before);
        expect(tester.widget<FilledButton>(file).onPressed, isNotNull);
        if (outcome != 'cancel') {
          expect(
            find.text(
              outcome == 'oversized'
                  ? l10n.importTextFileTooLarge(TextFilePicker.maxMegabytes)
                  : l10n.importFailedCheckContent,
            ),
            findsOneWidget,
          );
          await tester.drag(find.byType(SnackBar), const Offset(0, 100));
          await tester.pumpAndSettle();
        }
        await _configureAndReturn(tester, l10n);
        if (!web) _expectDraft(tester);
        expect(tester.takeException(), isNull);
      });
    }

    for (final apply in [false, true]) {
      testWidgets(
        '$entry uses the existing file confirmation and apply=$apply',
        (tester) async {
          final runtime = await _createRuntime();
          final before = runtime.workspaceView.data.toJson();
          final picker = _FilePicker(() async => _timetableFile(runtime));
          _usePicker(picker);
          final l10n = await _pumpEntry(tester, runtime, web: web);
          final file = find.widgetWithText(
            FilledButton,
            l10n.schoolImportFileAction,
          );
          await tester.tap(file);
          final confirm = find.widgetWithText(
            FilledButton,
            l10n.importBundledPeriodTimeSets,
          );
          await _pumpUntil(tester, () => confirm.evaluate().isNotEmpty);
          expect(runtime.workspaceView.data.toJson(), before);
          expect(tester.widget<FilledButton>(file).onPressed, isNull);
          if (apply) {
            await tester.tap(confirm);
          } else {
            await tester.binding.handlePopRoute();
          }
          await _pumpUntil(
            tester,
            () => tester.widget<FilledButton>(file).onPressed != null,
          );
          await tester.pumpAndSettle();
          expect(picker.calls, 1);
          if (apply) {
            expect(
              runtime.studentView.activeTimetable.config.name,
              'Local file timetable',
            );
            await tester.drag(find.byType(SnackBar), const Offset(0, 100));
            await tester.pumpAndSettle();
          } else {
            expect(runtime.workspaceView.data.toJson(), before);
          }
          await _configureAndReturn(tester, l10n);
          if (!web) _expectDraft(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '$entry discards a selected file after the data session changes',
      (tester) async {
        final runtime = await _createRuntime();
        final before = runtime.workspaceView.data.toJson();
        final pending = Completer<XFile?>();
        final picker = _FilePicker(() => pending.future);
        _usePicker(picker);
        final l10n = await _pumpEntry(tester, runtime, web: web);
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.schoolImportFileAction),
        );
        await tester.pump();
        final reservation = runtime.maintenance.reserve();
        runtime.maintenance.release(reservation);
        pending.complete(_timetableFile(runtime));
        await tester.pumpAndSettle();
        expect(runtime.workspaceView.data.toJson(), before);
        expect(find.text(l10n.importPeriodTimeSetDialogTitle), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$entry disables repeated actions until file selection completes',
      (tester) async {
        final runtime = await _createRuntime();
        final pending = Completer<XFile?>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete(null);
        });
        final picker = _FilePicker(() => pending.future);
        _usePicker(picker);
        final l10n = await _pumpEntry(tester, runtime, web: web);
        final file = find.widgetWithText(
          FilledButton,
          l10n.schoolImportFileAction,
        );
        await tester.tap(file);
        await tester.tap(file);
        await tester.pump();
        expect(picker.calls, 1);
        expect(tester.widget<FilledButton>(file).onPressed, isNull);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(
                  OutlinedButton,
                  l10n.schoolImportConfigureAction,
                ),
              )
              .onPressed,
          isNull,
        );
        pending.complete(null);
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(file).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
