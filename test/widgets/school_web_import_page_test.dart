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
      ),
      isTrue,
    );
    expect(
      shouldUseSchoolWebImportExtraction(
        extractionGeneration: 3,
        currentGeneration: 4,
        hasSuccessfulPageLoad: true,
      ),
      isFalse,
    );
    expect(
      shouldUseSchoolWebImportExtraction(
        extractionGeneration: 3,
        currentGeneration: 3,
        hasSuccessfulPageLoad: false,
      ),
      isFalse,
    );
  });

  test('a stale loading flag cannot reject an otherwise valid extraction', () {
    // Android reports no load-stop for in-page anchor navigation, so the
    // loading flag can stay true indefinitely. Import must not depend on it:
    // the generation comparison already catches a page that changed underneath
    // the extraction, and unlike a flag it cannot latch.
    expect(
      shouldUseSchoolWebImportExtraction(
        extractionGeneration: 7,
        currentGeneration: 7,
        hasSuccessfulPageLoad: true,
      ),
      isTrue,
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
    'app bar shows the site origin instead of a leading back button',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SchoolWebImportPage(
            site: SchoolSite(
              name: 'Example University',
              loginUrl: 'https://portal.example.edu/login?next=/timetable',
            ),
          ),
        ),
      );
      await tester.pump();

      // The closed lock already says "https", so only the host is shown.
      expect(find.text('portal.example.edu'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Example University'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('insecure origins keep the visible scheme and an open lock', (
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
            loginUrl: 'http://legacy.example.edu/login',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('http://legacy.example.edu'), findsOneWidget);
    expect(find.byIcon(Icons.lock_open_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a popup window never borrows the parent origin', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SchoolWebImportPage(
          windowId: 7,
          site: SchoolSite(
            name: 'Example University',
            loginUrl: 'https://portal.example.edu/login',
          ),
        ),
      ),
    );
    await tester.pump();

    // A popup opens with no URL of its own. Showing the opener's domain next to
    // a lock icon would label the new page with an origin that is not its own.
    expect(find.text('Unknown site'), findsOneWidget);
    expect(find.text('portal.example.edu'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back asks before leaving and stays put when cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SchoolWebImportPage(
                  site: SchoolSite(
                    name: 'Example University',
                    loginUrl: 'https://portal.example.edu/login',
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SchoolWebImportPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Leave the browser?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Leave the browser?'), findsNothing);
    expect(find.byType(SchoolWebImportPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back leaves the page once confirmed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SchoolWebImportPage(
                  site: SchoolSite(
                    name: 'Example University',
                    loginUrl: 'https://portal.example.edu/login',
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
    await tester.pumpAndSettle();

    expect(find.byType(SchoolWebImportPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
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
        l10n.openSettings,
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
        l10n.openSettings,
      );
      final messageRect = tester.getRect(message);
      final settingsButtonRect = tester.getRect(settingsButton);

      // getRect returns logical pixels, so the comparison point has to be the
      // logical centre, not the raw physical width.
      final screenCenter =
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;

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
