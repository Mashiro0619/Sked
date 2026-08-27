import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/school_import_parser_settings_page.dart';
import 'package:sked/screens/school_web_import_page.dart';
import 'package:sked/widgets/expressive_empty_state.dart';

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
    final settings = schoolWebImportWebViewSettings(supportsPopups: true);

    expect(settings.javaScriptEnabled, isTrue);
    expect(settings.javaScriptCanOpenWindowsAutomatically, isTrue);
    expect(settings.supportMultipleWindows, isTrue);
    expect(settings.thirdPartyCookiesEnabled, isTrue);
    expect(settings.useShouldOverrideUrlLoading, isFalse);
    expect(settings.regexToAllowSyncUrlLoading, isNull);
  });

  test('multi-window support is never enabled without a popup handler', () {
    // onCreateWindow is only attached when the platform supports windowId.
    // Leaving supportMultipleWindows on without it makes Android route
    // target=_blank into a window nobody creates, so the tap does nothing.
    final settings = schoolWebImportWebViewSettings(supportsPopups: false);

    expect(settings.supportMultipleWindows, isFalse);
    expect(settings.javaScriptCanOpenWindowsAutomatically, isFalse);
    expect(settings.thirdPartyCookiesEnabled, isTrue);
    expect(settings.useShouldOverrideUrlLoading, isFalse);
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

  testWidgets(
    'missing API configuration uses a compact prompt with a settings shortcut',
    (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = TimetableProvider();
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const SchoolWebImportPage(
              site: SchoolSite(
                name: '示例大学',
                loginUrl: 'https://example.edu/login',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SchoolWebImportPage));
      final l10n = AppLocalizations.of(context);
      final messageFinder = find.text(
        l10n.schoolImportParserCustomConfigIncomplete,
      );
      final settingsButton = find.widgetWithText(
        FilledButton,
        l10n.schoolImportParserSettingsTitle,
      );
      final importButton = find.ancestor(
        of: find.byIcon(Icons.file_download_outlined),
        matching: find.byType(IconButton),
      );

      expect(messageFinder, findsOneWidget);
      expect(settingsButton, findsOneWidget);
      expect(find.byType(ExpressiveEmptyState), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.widget<IconButton>(importButton).onPressed, isNull);
      expect(
        tester.widget<Text>(messageFinder).maxLines,
        isNull,
        reason: 'The configuration explanation must remain fully readable.',
      );
      expect(tester.takeException(), isNull);

      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.byType(SchoolWebImportPage), findsOneWidget);
      expect(messageFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing API configuration keeps compact content centered on wide screens',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = TimetableProvider();
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SchoolWebImportPage(
              site: SchoolSite(
                name: '示例大学',
                loginUrl: 'https://example.edu/login',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SchoolWebImportPage));
      final l10n = AppLocalizations.of(context);
      final message = find.text(l10n.schoolImportParserCustomConfigIncomplete);
      final settingsButton = find.widgetWithText(
        FilledButton,
        l10n.schoolImportParserSettingsTitle,
      );
      final messageRect = tester.getRect(message);
      final settingsButtonRect = tester.getRect(settingsButton);

      final screenCenter = tester.view.physicalSize.width / 2;

      expect(messageRect.center.dx, closeTo(screenCenter, 1));
      expect(settingsButtonRect.center.dx, closeTo(screenCenter, 1));
      expect(messageRect.top, greaterThan(200));
      expect(settingsButtonRect.top, greaterThan(messageRect.bottom));
      expect(tester.getRect(settingsButton).width, lessThan(280));
      expect(tester.getRect(settingsButton).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    },
  );
}
