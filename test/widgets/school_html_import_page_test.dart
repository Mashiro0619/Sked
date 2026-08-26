import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/screens/school_import_parser_settings_page.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/services/school_import_content_sanitizer.dart';
import 'package:sked/services/school_import_http_consent.dart';
import 'package:sked/services/privacy_service.dart';

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
  Future<String?> filePath() async => 'memory://school-html-import-test';
}

class _NoopPrivacyService extends PrivacyService {
  const _NoopPrivacyService();

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

class _RecordingSchoolImportApi extends SchoolImportApi {
  var callCount = 0;

  @override
  Stream<SchoolImportStreamEvent> importCurrentPageStream(
    SchoolImportPagePayload payload, {
    SchoolImportParserSettings? parserSettings,
    http.Client? client,
  }) {
    callCount += 1;
    return Stream.value(const ParseError('synthetic stop'));
  }
}

class _CloseTrackingClient extends http.BaseClient {
  final responseController = StreamController<List<int>>();
  bool sendCalled = false;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCalled = true;
    return http.StreamedResponse(responseController.stream, 200);
  }

  @override
  void close() {
    if (closed) return;
    closed = true;
    unawaited(responseController.close());
  }
}

AppData _buildConfiguredCustomParserData({
  String baseUrl = 'https://api.example.com/v1',
}) {
  final baseData = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: defaultLocaleCode,
  );
  return baseData.copyWith(
    activeMode: AppMode.student,
    aiApiSettings: AiApiSettings(
      source: schoolImportParserSourceCustomOpenAi,
      customBaseUrl: baseUrl,
      customApiKey: 'sk-test',
      customModel: 'gpt-4.1-mini',
    ),
  );
}

Future<TimetableProvider> _createProvider({
  String baseUrl = 'https://api.example.com/v1',
}) async {
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(
      _buildConfiguredCustomParserData(baseUrl: baseUrl),
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    privacyService: const _NoopPrivacyService(),
  );
  await provider.load();
  return provider;
}

Future<AppLocalizations> _pumpAndCaptureL10n(WidgetTester tester) async {
  AppLocalizations? captured;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = AppLocalizations.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
  return captured!;
}

Future<void> _pumpSchoolHtmlImportPage(
  WidgetTester tester,
  TimetableProvider provider, {
  SchoolImportApi? api,
  SchoolImportHttpConsentStore? httpConsentStore,
  http.Client Function()? httpClientFactory,
  String initialContent = '',
  bool initialContentTruncated = false,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SchoolHtmlImportPage(
          initialContent: initialContent,
          initialContentTruncated: initialContentTruncated,
          api: api,
          httpConsentStore: httpConsentStore,
          httpClientFactory: httpClientFactory,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSchoolHtmlImportPageHost(
  WidgetTester tester,
  TimetableProvider provider,
) async {
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SchoolHtmlImportPage(
                        showReturnToWebPageButton: true,
                      ),
                    ),
                  ),
                  child: const Text('Open import page'),
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

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('mapSchoolImportApplyError returns FormatException message', (
    tester,
  ) async {
    final l10n = await _pumpAndCaptureL10n(tester);

    expect(
      mapSchoolImportApplyError(const FormatException('bad payload'), l10n),
      'bad payload',
    );
  });

  testWidgets('mapSchoolImportApplyError falls back to localized message for '
      'non-FormatException errors', (tester) async {
    final l10n = await _pumpAndCaptureL10n(tester);

    expect(
      mapSchoolImportApplyError(Exception('boom'), l10n),
      l10n.importFailedCheckContent,
    );
    expect(
      mapSchoolImportApplyError(StateError('bad state'), l10n),
      l10n.importFailedCheckContent,
    );
  });

  testWidgets('parser settings are no longer nested in the import page', (
    tester,
  ) async {
    final provider = await _createProvider();
    await _pumpSchoolHtmlImportPage(tester, provider);

    expect(find.text('AI API configuration'), findsNothing);
    expect(find.byType(SchoolImportParserSettingsPage), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('unconfigured parser offers a direct settings shortcut', (
    tester,
  ) async {
    final provider = await _createProvider(baseUrl: '');
    await _pumpSchoolHtmlImportPage(tester, provider);

    final openSettingsButton = find.widgetWithText(
      FilledButton,
      'Open settings',
    );
    expect(openSettingsButton, findsOneWidget);

    await tester.tap(openSettingsButton);
    await tester.pumpAndSettle();

    expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
  });

  testWidgets('import actions stay usable in a narrow viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider();
    await _pumpSchoolHtmlImportPage(
      tester,
      provider,
      initialContent: 'Monday period 1 Mathematics',
    );

    expect(find.text('Prepare content'), findsOneWidget);
    expect(find.text('Parse and import'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('return to webpage button cannot pop the parent route twice', (
    tester,
  ) async {
    final provider = await _createProvider();
    await _pumpSchoolHtmlImportPageHost(tester, provider);

    final openButton = find.widgetWithText(FilledButton, 'Open import page');
    expect(openButton, findsOneWidget);

    await tester.tap(openButton);
    await _pumpRouteTransition(tester);

    final returnButton = find.widgetWithText(TextButton, 'Back to webpage');
    expect(returnButton, findsOneWidget);

    await tester.tap(returnButton);
    await tester.tap(returnButton, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(SchoolHtmlImportPage), findsNothing);
    expect(openButton, findsOneWidget);
  });

  testWidgets('HTTP parsing never starts before explicit confirmation', (
    tester,
  ) async {
    final provider = await _createProvider(
      baseUrl: 'http://api.example.com/v1',
    );
    final api = _RecordingSchoolImportApi();
    await _pumpSchoolHtmlImportPage(
      tester,
      provider,
      api: api,
      httpConsentStore: SchoolImportHttpConsentStore(),
    );

    await tester.enterText(
      find.byType(TextField),
      '<table><tr><td>A</td></tr></table>',
    );
    final submitButton = find.text('Parse and import');
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Use an unencrypted HTTP endpoint?'), findsOneWidget);
    expect(api.callCount, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(api.callCount, 0);

    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.callCount, 1);
  });

  testWidgets('disposing the page closes an in-flight parser client', (
    tester,
  ) async {
    final provider = await _createProvider();
    final client = _CloseTrackingClient();
    await _pumpSchoolHtmlImportPage(
      tester,
      provider,
      httpClientFactory: () => client,
    );

    await tester.enterText(find.byType(TextField), 'Monday period 1 Math');
    final submitButton = find.text('Parse and import');
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(client.sendCalled, isTrue);
    expect(client.closed, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(client.closed, isTrue);
  });

  testWidgets('shows when webpage capture reached the safe limit', (
    tester,
  ) async {
    final provider = await _createProvider();
    await _pumpSchoolHtmlImportPage(
      tester,
      provider,
      initialContent: '<table><tr><td>Captured</td></tr></table>',
      initialContentTruncated: true,
    );

    expect(
      find.text(
        'This page reached the safe import limit. Only the captured portion will be sent for parsing.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('clears the capture limit warning after replacing the content', (
    tester,
  ) async {
    final provider = await _createProvider();
    await _pumpSchoolHtmlImportPage(
      tester,
      provider,
      initialContent: '<table><tr><td>Captured</td></tr></table>',
      initialContentTruncated: true,
    );
    const warning =
        'This page reached the safe import limit. Only the captured portion will be sent for parsing.';
    expect(find.text(warning), findsOneWidget);

    final textField = tester.widget<TextField>(find.byType(TextField));
    final controller = textField.controller!;
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    await tester.enterText(find.byType(TextField), 'Monday period 1 Math');
    await tester.pump();

    expect(find.text(warning), findsNothing);
  });

  testWidgets('restores the capture warning when undo restores its content', (
    tester,
  ) async {
    const captured = '<table><tr><td>Captured</td></tr></table>';
    const warning =
        'This page reached the safe import limit. Only the captured portion will be sent for parsing.';
    final provider = await _createProvider();
    await _pumpSchoolHtmlImportPage(
      tester,
      provider,
      initialContent: captured,
      initialContentTruncated: true,
    );

    final finder = find.byType(TextField);
    final controller = tester.widget<TextField>(finder).controller!;
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    await tester.enterText(finder, 'Monday period 1 Math');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(warning), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(controller.text, captured);
    expect(find.text(warning), findsOneWidget);
  });

  testWidgets(
    'keeps pasted-content truncation warning after a one-character deletion',
    (tester) async {
      final provider = await _createProvider();
      await _pumpSchoolHtmlImportPage(tester, provider);
      const emoji = '\u{1f600}';
      final oversizedInput =
          emoji * (SchoolImportContentSanitizer.maxInputLength ~/ 2 + 1);

      await tester.enterText(find.byType(TextField), oversizedInput);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(
        textField.controller?.text.length,
        SchoolImportContentSanitizer.maxInputLength,
      );
      expect(
        textField.controller?.text.runes.length,
        SchoolImportContentSanitizer.maxInputLength ~/ 2,
      );
      expect(
        find.text(
          'This page reached the safe import limit. Only the captured portion will be sent for parsing.',
        ),
        findsOneWidget,
      );

      final controller = textField.controller!;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await tester.enterText(
        find.byType(TextField),
        controller.text.substring(0, controller.text.length - emoji.length),
      );
      await tester.pump();

      expect(
        find.text(
          'This page reached the safe import limit. Only the captured portion will be sent for parsing.',
        ),
        findsOneWidget,
      );
    },
  );
}
