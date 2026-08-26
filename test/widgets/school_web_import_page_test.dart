import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/screens/school_web_import_page.dart';

void main() {
  test('origin display removes paths, credentials, query, and fragment', () {
    expect(
      schoolWebImportOrigin(
        'https://user:secret@school.example.test:443/path?token=1#week',
      ),
      'https://school.example.test',
    );
    expect(
      schoolWebImportOrigin('http://school.example.test:8080/login'),
      'http://school.example.test:8080',
    );
    expect(schoolWebImportOrigin('javascript:alert(1)'), isNull);
  });

  test('WebView leaves navigation entirely to the platform browser', () {
    final settings = schoolWebImportWebViewSettings();

    expect(settings.javaScriptEnabled, isTrue);
    expect(settings.javaScriptCanOpenWindowsAutomatically, isTrue);
    expect(settings.supportMultipleWindows, isTrue);
    expect(settings.thirdPartyCookiesEnabled, isTrue);
    expect(settings.useShouldOverrideUrlLoading, isFalse);
    expect(settings.regexToAllowSyncUrlLoading, isNull);
  });

  test('load completion rejects stale and partial callbacks', () {
    const url = 'https://school.example.test/timetable';

    expect(
      shouldAcceptSchoolWebImportLoadCompletion(
        isLoading: true,
        awaitingLoadStart: false,
        callbackUrl: url,
        controllerUrl: url,
        progress: 100,
      ),
      isTrue,
    );
    expect(
      shouldAcceptSchoolWebImportLoadCompletion(
        isLoading: true,
        awaitingLoadStart: false,
        callbackUrl: 'https://old.example.test',
        controllerUrl: url,
        progress: 100,
      ),
      isFalse,
    );
    expect(
      shouldAcceptSchoolWebImportLoadCompletion(
        isLoading: true,
        awaitingLoadStart: false,
        callbackUrl: url,
        controllerUrl: url,
        progress: 50,
      ),
      isFalse,
    );
    expect(
      shouldAcceptSchoolWebImportLoadCompletion(
        isLoading: false,
        awaitingLoadStart: false,
        callbackUrl: url,
        controllerUrl: url,
        progress: 100,
      ),
      isFalse,
    );
    expect(
      shouldAcceptSchoolWebImportLoadCompletion(
        isLoading: true,
        awaitingLoadStart: true,
        callbackUrl: url,
        controllerUrl: url,
        progress: 100,
      ),
      isFalse,
    );
  });

  test('page extraction is discarded after any navigation state change', () {
    expect(
      shouldUseSchoolWebImportExtraction(
        extractionGeneration: 3,
        currentGeneration: 3,
        hasSuccessfulPageLoad: true,
        isLoadingPage: false,
      ),
      isTrue,
    );
    expect(
      shouldUseSchoolWebImportExtraction(
        extractionGeneration: 3,
        currentGeneration: 4,
        hasSuccessfulPageLoad: true,
        isLoadingPage: false,
      ),
      isFalse,
    );
    expect(
      shouldUseSchoolWebImportExtraction(
        extractionGeneration: 3,
        currentGeneration: 3,
        hasSuccessfulPageLoad: false,
        isLoadingPage: false,
      ),
      isFalse,
    );
    expect(
      shouldUseSchoolWebImportExtraction(
        extractionGeneration: 3,
        currentGeneration: 3,
        hasSuccessfulPageLoad: true,
        isLoadingPage: true,
      ),
      isFalse,
    );
  });

  testWidgets('initial school load waits until inherited widgets are ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SchoolWebImportPage(
          site: SchoolSite(
            name: 'Example University',
            loginUrl: 'https://example.edu/login',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('web toolbar stays compact and labeled on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const SchoolWebImportPage(
          site: SchoolSite(
            name: 'Example University with a very long translated name',
            loginUrl: 'https://example.edu/login',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Previous page'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
