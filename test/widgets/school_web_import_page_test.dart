import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/school_import_parser_settings_page.dart';
import 'package:sked/screens/school_web_import_page.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/widgets/expressive_empty_state.dart';

const _site = SchoolSite(
  name: 'Example University',
  loginUrl: 'https://portal.example.edu/login?next=/timetable',
);

Finder _iconButtonWithTooltip(String tooltip) => find.ancestor(
  of: find.byTooltip(tooltip),
  matching: find.byType(IconButton),
);

Finder _tooltipWithMessage(String message) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && widget.message == message,
);

Widget _browserApp({
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  TimetableProvider? provider,
  Widget? home,
  SchoolWebImportWebViewBuilder? webViewBuilder,
  Future<List<SchoolSite>> Function()? loadSites,
  bool? supportsPopupWindows,
}) {
  final app = MaterialApp(
    locale: locale,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home:
        home ??
        SchoolWebImportPage(
          site: _site,
          webViewBuilder: webViewBuilder,
          loadSites: loadSites,
          supportsPopupWindows: supportsPopupWindows,
        ),
  );
  if (provider == null) {
    return app;
  }
  return ChangeNotifierProvider<TimetableProvider>.value(
    value: provider,
    child: app,
  );
}

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
  Future<String?> filePath() async => 'memory://school-web-import-test';
}

class _NoopPrivacyService extends PrivacyService {
  const _NoopPrivacyService();

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

Future<TimetableProvider> _createConfiguredProvider() async {
  final initial =
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        aiApiSettings: const AiApiSettings(
          source: schoolImportParserSourceCustomOpenAi,
          customBaseUrl: 'https://api.example.test/v1',
          customApiKey: 'sk-test',
          customModel: 'gpt-test',
        ),
      );
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(initial),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    privacyService: const _NoopPrivacyService(),
  );
  await provider.load();
  return provider;
}

class _FakeWebViewController extends Fake implements InAppWebViewController {
  WebUri? currentUrl;
  int? progress = 100;
  bool canGoBackResult = false;
  bool failCanGoBack = false;
  bool failLoad = false;
  bool failGoBack = false;
  bool failGetUrl = false;
  Object? javascriptResult;
  Object? javascriptError;
  final List<String> loadedAddresses = <String>[];
  var getProgressCalls = 0;
  var reloadCalls = 0;
  var goBackCalls = 0;
  var stopLoadingCalls = 0;

  @override
  Future<WebUri?> getUrl() async {
    if (failGetUrl) {
      throw StateError('Synthetic current-url failure');
    }
    return currentUrl;
  }

  @override
  Future<int?> getProgress() async {
    getProgressCalls += 1;
    return progress;
  }

  @override
  Future<bool> canGoBack() async {
    if (failCanGoBack) {
      throw StateError('Synthetic can-go-back failure');
    }
    return canGoBackResult;
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    if (failLoad) {
      throw StateError('Synthetic load failure');
    }
    currentUrl = urlRequest.url;
    loadedAddresses.add(urlRequest.url.toString());
  }

  @override
  Future<void> reload() async {
    if (failLoad) {
      throw StateError('Synthetic reload failure');
    }
    reloadCalls += 1;
  }

  @override
  Future<void> goBack() async {
    if (failGoBack) {
      throw StateError('Synthetic go-back failure');
    }
    goBackCalls += 1;
  }

  @override
  Future<void> stopLoading() async {
    stopLoadingCalls += 1;
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    if (javascriptError != null) {
      throw javascriptError!;
    }
    return javascriptResult;
  }
}

class _WebViewHarness {
  final List<SchoolWebImportWebViewConfiguration> configurations =
      <SchoolWebImportWebViewConfiguration>[];

  Widget build(SchoolWebImportWebViewConfiguration configuration) {
    configurations.add(configuration);
    return ColoredBox(
      key: configuration.key,
      color: Colors.transparent,
      child: Text('pane-${configuration.windowId ?? 'root'}'),
    );
  }

  SchoolWebImportWebViewConfiguration pane({int? windowId}) =>
      configurations.lastWhere((item) => item.windowId == windowId);
}

Widget _browserRouteHost() {
  return Builder(
    builder: (context) => TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SchoolWebImportPage(site: _site),
          ),
        );
      },
      child: const Text('open'),
    ),
  );
}

void main() {
  group('school web import browser helpers', () {
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

    test('address editor normalizes safe HTTP(S) addresses', () {
      expect(
        schoolWebImportAddress(' school.example.test/timetable?week=2#today '),
        'https://school.example.test/timetable?week=2#today',
      );
      expect(
        schoolWebImportAddress(
          'https://student:secret@school.example.test/login',
        ),
        'https://school.example.test/login',
      );
      expect(
        schoolWebImportAddress('http://school.example.test:8080/login'),
        'http://school.example.test:8080/login',
      );
    });

    test('address input strips user info before it reaches the browser', () {
      const disguisedAddress =
          'https://trusted.school.example@identity.example.test:8443/'
          'callback?ticket=abc#courses';

      // The text before @ is user info, not the host. Retaining it in the
      // address bar would both leak a credential and make the destination look
      // like a different school site.
      final normalized = schoolWebImportAddress(disguisedAddress);
      final origin = schoolWebImportOrigin(disguisedAddress);

      expect(
        normalized,
        'https://identity.example.test:8443/callback?ticket=abc#courses',
      );
      expect(origin, 'https://identity.example.test:8443');
      expect(normalized, isNot(contains('@')));
      expect(normalized, isNot(contains('trusted.school.example')));
      expect(origin, isNot(contains('@')));
      expect(origin, isNot(contains('trusted.school.example')));
    });

    test(
      'address input removes a username and password without losing route',
      () {
        final normalized = schoolWebImportAddress(
          'https://student:secret@school.example.test/timetable?week=2#today',
        );

        expect(
          normalized,
          'https://school.example.test/timetable?week=2#today',
        );
        expect(normalized, isNot(contains('student')));
        expect(normalized, isNot(contains('secret')));
        expect(normalized, isNot(contains('@')));
      },
    );

    test('address editor rejects unsupported and incomplete addresses', () {
      for (final source in <String>[
        '',
        'https://',
        'javascript:alert(1)',
        'file:///timetable.html',
        'https://school.example.test/contains whitespace',
        'https://school.example.test:invalid-port/login',
      ]) {
        expect(schoolWebImportAddress(source), isNull, reason: source);
        expect(schoolWebImportOrigin(source), isNull, reason: source);
      }
    });

    test('system Back follows web history, then popup, then browser exit', () {
      for (final testCase
          in <
            ({
              bool canGoBack,
              bool isPopupPane,
              SchoolWebImportBackAction expected,
            })
          >[
            (
              canGoBack: true,
              isPopupPane: false,
              expected: SchoolWebImportBackAction.webHistory,
            ),
            // A popup with web history must go back in that same WebView first;
            // closing the pane at this point would discard its authentication flow.
            (
              canGoBack: true,
              isPopupPane: true,
              expected: SchoolWebImportBackAction.webHistory,
            ),
            (
              canGoBack: false,
              isPopupPane: true,
              expected: SchoolWebImportBackAction.closePopup,
            ),
            (
              canGoBack: false,
              isPopupPane: false,
              expected: SchoolWebImportBackAction.exitBrowser,
            ),
          ]) {
        expect(
          schoolWebImportBackAction(
            canGoBack: testCase.canGoBack,
            isPopupPane: testCase.isPopupPane,
          ),
          testCase.expected,
          reason:
              'canGoBack=${testCase.canGoBack}, popup=${testCase.isPopupPane}',
        );
      }
    });

    test(
      'WebView leaves normal navigation entirely to the platform browser',
      () {
        final settings = schoolWebImportWebViewSettings(supportsPopups: true);

        expect(settings.javaScriptEnabled, isTrue);
        expect(settings.javaScriptCanOpenWindowsAutomatically, isTrue);
        expect(settings.supportMultipleWindows, isTrue);
        expect(settings.thirdPartyCookiesEnabled, isTrue);
        expect(settings.useShouldOverrideUrlLoading, isFalse);
        expect(settings.regexToAllowSyncUrlLoading, isNull);
      },
    );

    test('multi-window support is disabled without a native popup pane', () {
      final settings = schoolWebImportWebViewSettings(supportsPopups: false);

      expect(settings.supportMultipleWindows, isFalse);
      expect(settings.javaScriptCanOpenWindowsAutomatically, isFalse);
      expect(settings.thirdPartyCookiesEnabled, isTrue);
      expect(settings.useShouldOverrideUrlLoading, isFalse);
    });

    test('only the supported desktop browser shows a page-history action', () {
      expect(
        schoolWebImportShowsDesktopBackButton(
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          schoolWebImportShowsDesktopBackButton(
            isWeb: false,
            platform: platform,
          ),
          isFalse,
          reason: platform.name,
        );
      }
      expect(
        schoolWebImportShowsDesktopBackButton(
          isWeb: true,
          platform: TargetPlatform.windows,
        ),
        isFalse,
      );
    });

    test('Windows terminal completion trusts a valid callback URL', () {
      const url = 'https://school.example.test/timetable';

      expect(
        shouldAcceptSchoolWebImportLoadCompletion(
          callbackUrl: url,
          controllerUrl: url,
        ),
        isTrue,
        reason:
            'When the load-start callback never arrives, the watchdog releases '
            'the acknowledgement fence so a late matching completion remains '
            'authoritative.',
      );
      expect(
        shouldAcceptSchoolWebImportLoadCompletion(
          callbackUrl: url,
          controllerUrl: url,
        ),
        isTrue,
        reason:
            'A native controller can omit onLoadStart for an imperative '
            'history operation, so its matching terminal stop is accepted.',
      );
      expect(
        shouldAcceptSchoolWebImportLoadCompletion(
          callbackUrl: 'https://old.example.test',
          controllerUrl: url,
        ),
        isFalse,
      );
      expect(
        shouldAcceptSchoolWebImportLoadCompletion(
          callbackUrl: 'https://redirected.example.test/timetable',
          controllerUrl: url,
          expectedUrl: 'https://redirected.example.test/timetable#courses',
          terminalCallbackIsAuthoritative: true,
        ),
        isTrue,
        reason:
            'WebView2 can retain the previous controller URL while reporting '
            'the final navigation URL through onLoadStop.',
      );
      expect(
        shouldAcceptSchoolWebImportLoadCompletion(
          callbackUrl: url,
          controllerUrl: url,
        ),
        isTrue,
        reason:
            'A matching terminal load-stop is authoritative on Windows even '
            'when its platform progress value is stale.',
      );
      expect(
        shouldAcceptSchoolWebImportLoadCompletion(
          callbackUrl: url,
          controllerUrl: '',
          expectedUrl: 'https://old.example.test/redirect',
          terminalCallbackIsAuthoritative: true,
        ),
        isTrue,
        reason:
            'A WebView2 terminal callback must not be rejected just because '
            'the controller or pre-redirect pane URL is stale.',
      );
      expect(
        shouldAcceptSchoolWebImportLoadCompletion(
          callbackUrl: '$url?week=1',
          controllerUrl: '$url?week=2',
          expectedUrl: '$url?week=2',
          terminalCallbackIsAuthoritative: true,
        ),
        isTrue,
        reason:
            'The native terminal URL is authoritative after the pane and '
            'controller identity have been checked by the caller.',
      );
      expect(
        shouldAcceptSchoolWebImportLoadCompletion(
          callbackUrl: '',
          controllerUrl: url,
        ),
        isFalse,
      );
      expect(
        schoolWebImportTreatsTerminalLoadStopAsAuthoritative(
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
      expect(
        schoolWebImportTreatsTerminalLoadStopAsAuthoritative(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });

    test('page extraction is discarded when its navigation state is no longer current', () {
      expect(
        shouldUseSchoolWebImportExtraction(
          extractionGeneration: 3,
          currentGeneration: 3,
        ),
        isTrue,
      );
      expect(
        shouldUseSchoolWebImportExtraction(
          extractionGeneration: 3,
          currentGeneration: 4,
        ),
        isFalse,
      );
    });
  });

  group('school web import browser shell', () {
    testWidgets('initial school load waits until inherited widgets are ready', (
      tester,
    ) async {
      await tester.pumpWidget(_browserApp());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Windows browser shell has explicit exit and page-history controls',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _browserApp(textScaler: const TextScaler.linear(2)),
        );
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        final exit = find.byTooltip(l10n.schoolWebImportExitBrowser);

        expect(exit, findsOneWidget);
        expect(
          find.byTooltip(l10n.schoolWebImportEditAddress),
          findsNothing,
          reason: 'The address control is disabled until its WebView exists.',
        );
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets('Android browser shell omits desktop browser controls', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(_browserApp());
      await tester.pump();

      final context = tester.element(find.byType(SchoolWebImportPage));
      final l10n = AppLocalizations.of(context);
      expect(find.byTooltip(l10n.schoolWebImportExitBrowser), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'address title shows a safe site origin rather than credentials',
      (tester) async {
        await tester.pumpWidget(_browserApp());
        await tester.pump();

        expect(find.text('portal.example.edu'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsNothing);
        expect(find.byIcon(Icons.lock_open_outlined), findsNothing);
        expect(find.text(_site.name), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Windows explicit exit opens one confirmation and can be cancelled',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await tester.pumpWidget(_browserApp(home: _browserRouteHost()));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        await tester.tap(find.byTooltip(l10n.schoolWebImportExitBrowser));
        await tester.pumpAndSettle();

        expect(find.text(l10n.schoolWebImportExitTitle), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pumpAndSettle();

        expect(find.text(l10n.schoolWebImportExitTitle), findsNothing);
        expect(find.byType(SchoolWebImportPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'system Back exits only after confirming when no web history exists',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await tester.pumpWidget(_browserApp(home: _browserRouteHost()));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text(l10n.schoolWebImportExitTitle), findsOneWidget);
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.schoolWebImportExitConfirm),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SchoolWebImportPage), findsNothing);
        expect(find.text('open'), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'missing API configuration keeps a readable shortcut on a narrow screen',
      (tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = TimetableProvider();
        addTearDown(provider.dispose);

        await tester.pumpWidget(
          _browserApp(
            locale: const Locale('zh'),
            textScaler: const TextScaler.linear(2),
            provider: provider,
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        final message = find.text(
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

        expect(message, findsOneWidget);
        expect(settingsButton, findsOneWidget);
        expect(find.byType(ExpressiveEmptyState), findsNothing);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(tester.widget<IconButton>(importButton).onPressed, isNull);
        expect(tester.widget<Text>(message).maxLines, isNull);
        expect(tester.getRect(settingsButton).height, greaterThanOrEqualTo(48));

        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('missing API configuration stays centered on wide screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = TimetableProvider();
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        _browserApp(locale: const Locale('zh'), provider: provider),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SchoolWebImportPage));
      final l10n = AppLocalizations.of(context);
      final message = find.text(l10n.schoolImportParserCustomConfigIncomplete);
      final settingsButton = find.widgetWithText(
        FilledButton,
        l10n.openSettings,
      );
      final screenCenter =
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;

      expect(tester.getRect(message).center.dx, closeTo(screenCenter, 1));
      expect(
        tester.getRect(settingsButton).center.dx,
        closeTo(screenCenter, 1),
      );
      expect(tester.getRect(settingsButton).width, lessThan(280));
      expect(tester.getRect(settingsButton).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Windows terminal completion enables importing when controller URL lags the callback',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController()..progress = 0;

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();

        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        await tester.pump();
        expect(controller.loadedAddresses, <String>[_site.loginUrl]);

        harness.pane().onLoadStart(controller, WebUri(_site.loginUrl));
        await tester.pump();
        harness.pane().onLoadStart(
          controller,
          WebUri('https://portal.example.edu/timetable'),
        );
        await tester.pump();
        controller.currentUrl = WebUri('https://identity.example.edu/callback');
        harness.pane().onLoadStop(
          controller,
          WebUri('https://portal.example.edu/timetable'),
        );
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        expect(
          tester
              .widget<IconButton>(
                _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          controller.getProgressCalls,
          0,
          reason:
              'flutter_inappwebview_windows does not implement getProgress, '
              'so onLoadStop must not query it before making the page ready.',
        );
        expect(
          _tooltipWithMessage(l10n.schoolWebImportEditAddress),
          findsOneWidget,
        );

        final addressControl = _tooltipWithMessage(
          l10n.schoolWebImportEditAddress,
        );
        final addressRect = tester.getRect(addressControl);
        expect(addressRect.height, greaterThanOrEqualTo(48));
        expect(addressRect.width, greaterThan(96));
        await tester.tapAt(
          Offset(addressRect.right - 8, addressRect.center.dy),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.schoolWebImportEditAddress), findsOneWidget);
        await tester.enterText(
          find.byType(TextField),
          'example.edu/portal?week=2',
        );
        await tester.testTextInput.receiveAction(TextInputAction.go);
        await tester.pumpAndSettle();

        expect(
          controller.loadedAddresses.last,
          'https://example.edu/portal?week=2',
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'Windows load callbacks never show a progress bar or block browser actions',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController()..progress = 100;

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        final import = _iconButtonWithTooltip(
          l10n.schoolWebImportImportCurrentPage,
        );
        final refresh = _iconButtonWithTooltip(
          MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
        );
        harness.pane().onLoadStart(controller, WebUri(_site.loginUrl));
        harness.pane().onProgressChanged(controller, 100);
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);
        expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);
        expect(
          _tooltipWithMessage(l10n.schoolWebImportEditAddress),
          findsOneWidget,
        );

        // WebView2 may leave a long-running request open after the document is
        // usable. The address field must still let the user leave or replace it.
        await tester.tap(_tooltipWithMessage(l10n.schoolWebImportEditAddress));
        await tester.pumpAndSettle();
        expect(find.text(l10n.schoolWebImportEditAddress), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pumpAndSettle();

        // A terminal document callback can still update the displayed address,
        // but it is not a prerequisite for refresh or import.
        controller.currentUrl = WebUri('https://identity.example.edu/lagging');
        harness.pane().onDOMContentLoaded(
          controller,
          WebUri('https://portal.example.edu/timetable?week=1'),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);
        expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);
        expect(find.text('portal.example.edu'), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'Windows DOMContentLoaded accepts a redirect back without locking actions after a failed navigation',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();
        const secondAddress = 'https://portal.example.edu/timetable';
        const thirdAddress = 'https://portal.example.edu/failed';

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        final import = _iconButtonWithTooltip(
          l10n.schoolWebImportImportCurrentPage,
        );
        harness.pane().onLoadStart(controller, WebUri(_site.loginUrl));
        harness.pane().onLoadStart(controller, WebUri(secondAddress));
        await tester.pump();

        // The school sign-in flow may temporarily leave the timetable page and
        // ultimately render that exact prior address again. WebView2 reports
        // the source that is actually on screen for DOMContentLoaded, so this
        // must settle rather than leaving the browser indefinitely locked.
        harness.pane().onDOMContentLoaded(controller, WebUri(_site.loginUrl));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);

        harness.pane().onLoadStart(controller, WebUri(thirdAddress));
        await tester.pump();
        harness.pane().onReceivedError(
          controller,
          WebResourceRequest(url: WebUri(thirdAddress), isForMainFrame: true),
          WebResourceError(
            description: 'Synthetic main-frame failure',
            type: WebResourceErrorType.UNKNOWN,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);

        // A late callback cannot change the import control into a loading gate.
        harness.pane().onDOMContentLoaded(controller, WebUri(thirdAddress));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'Windows DOMContentLoaded accepts a redirect back to the prior address without load start',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        await tester.pump();
        harness.pane().onDOMContentLoaded(controller, WebUri(_site.loginUrl));
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        final import = _iconButtonWithTooltip(
          l10n.schoolWebImportImportCurrentPage,
        );
        await tester.tap(_tooltipWithMessage(l10n.schoolWebImportEditAddress));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'https://identity.example.edu/continue',
        );
        await tester.testTextInput.receiveAction(TextInputAction.go);
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);

        // No load-start is received for this redirect, and its final address
        // is the same as the page it left. The parsed-document event is still
        // authoritative because no newer native start proves it stale.
        harness.pane().onDOMContentLoaded(controller, WebUri(_site.loginUrl));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'Windows terminal completion accepts a redirected final URL and publishes it',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();
        const requestedAddress = 'https://identity.example.edu/continue';
        const finalAddress = 'https://timetable.example.edu/week?week=2';

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        await tester.pump();
        harness.pane().onLoadStart(controller, WebUri(_site.loginUrl));
        await tester.pump();
        harness.pane().onLoadStart(controller, WebUri(requestedAddress));
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        final import = _iconButtonWithTooltip(
          l10n.schoolWebImportImportCurrentPage,
        );
        controller.currentUrl = WebUri('https://old.example.edu/login');
        harness.pane().onLoadStop(controller, WebUri(finalAddress));
        await tester.pump();
        await tester.pump();

        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);
        expect(find.text('timetable.example.edu'), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'Windows progress and watchdog expiry never block importing or address editing',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        await tester.pump();
        expect(controller.loadedAddresses, <String>[_site.loginUrl]);

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        final import = _iconButtonWithTooltip(
          l10n.schoolWebImportImportCurrentPage,
        );
        final addressControl = _tooltipWithMessage(
          l10n.schoolWebImportEditAddress,
        );
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);
        // WebView2 can miss onLoadStart while a usable document is visible.
        // The root address editor must remain available so the user can leave
        // that page instead of waiting for an arbitrary timeout.
        expect(addressControl, findsOneWidget);
        await tester.tap(addressControl);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(l10n.schoolWebImportEditAddress), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pump(const Duration(milliseconds: 300));

        harness.pane().onLoadStart(controller, WebUri(_site.loginUrl));
        await tester.pump();

        harness.pane().onProgressChanged(controller, 99);
        await tester.pump();
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);

        harness.pane().onProgressChanged(controller, 100);
        await tester.pump();
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);

        await tester.pump(const Duration(seconds: 31));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<IconButton>(import).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'Windows Back and reload accept terminal completion without load start',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        harness.pane().onLoadStop(controller, WebUri(_site.loginUrl));
        await tester.pump();
        await tester.pump();

        final back = find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(IconButton),
        );
        expect(back, findsOneWidget);
        expect(
          tester.widget<IconButton>(back).onPressed,
          isNull,
          reason:
              'A root WebView with no native history must not expose a '
              'misleading Back action.',
        );

        await tester.tap(back);
        await tester.pump();
        await tester.pump();
        expect(controller.goBackCalls, 0);
        expect(find.byType(SchoolWebImportPage), findsOneWidget);

        controller.canGoBackResult = true;
        harness.pane().onUpdateVisitedHistory(
          controller,
          WebUri('https://portal.example.edu/timetable/week-2'),
          false,
        );
        await tester.pump();
        await tester.pump();
        expect(tester.widget<IconButton>(back).onPressed, isNotNull);
        await tester.tap(back);
        await tester.pump();
        await tester.pump();
        expect(controller.goBackCalls, 1);

        // WebView2 can omit the new onLoadStart for a history navigation. The
        // terminal callback must still publish the actual previous document.
        harness.pane().onLoadStop(
          controller,
          WebUri('https://previous.example.edu/timetable'),
        );
        await tester.pump();
        await tester.pump();
        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        expect(find.text('previous.example.edu'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          _tooltipWithMessage(l10n.schoolWebImportEditAddress),
          findsOneWidget,
        );

        final refresh = find.ancestor(
          of: find.byIcon(Icons.refresh),
          matching: find.byType(IconButton),
        );
        await tester.tap(refresh);
        await tester.pump();
        await tester.pump();
        expect(controller.reloadCalls, 1);
        harness.pane().onLoadStop(
          controller,
          WebUri('https://previous.example.edu/timetable'),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          tester
              .widget<IconButton>(
                _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'a redirected terminal load stop makes a page importable when Windows omits load start',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController()..progress = 0;

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        controller.currentUrl = WebUri('https://identity.example.edu/lagging');
        harness.pane().onLoadStop(
          controller,
          WebUri('https://timetable.example.edu/finished?week=1'),
        );
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        expect(
          tester
              .widget<IconButton>(
                _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.text('timetable.example.edu'), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'Windows address navigation accepts a redirected terminal load stop without load start',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        harness.pane().onLoadStop(controller, WebUri(_site.loginUrl));
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        await tester.tap(_tooltipWithMessage(l10n.schoolWebImportEditAddress));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(
          find.byType(TextField),
          'https://identity.example.edu/continue',
        );
        await tester.testTextInput.receiveAction(TextInputAction.go);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(
          controller.loadedAddresses.last,
          'https://identity.example.edu/continue',
        );

        controller.currentUrl = WebUri('https://old.example.edu/lagging');
        harness.pane().onLoadStop(
          controller,
          WebUri('https://redirected.example.edu/timetable'),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('redirected.example.edu'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'desktop Back traverses popup history then closes the popup at its root',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final rootController = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(rootController);
        await tester.pump();

        final popupAction = CreateWindowAction(
          windowId: 41,
          request: URLRequest(url: WebUri('https://login.example.edu/popup')),
          isForMainFrame: true,
        );
        expect(
          await harness.pane().onCreateWindow(rootController, popupAction),
          isTrue,
        );
        await tester.pump();
        expect(find.text('pane-41'), findsOneWidget);

        final popupController = _FakeWebViewController()
          ..currentUrl = WebUri('https://login.example.edu/popup')
          ..canGoBackResult = true;
        harness.pane(windowId: 41).onWebViewCreated(popupController);
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        final refresh = find.ancestor(
          of: find.byIcon(Icons.refresh),
          matching: find.byType(IconButton),
        );
        expect(
          tester.widget<IconButton>(refresh).onPressed,
          isNotNull,
          reason:
              'The popup browser must not hold Refresh behind native load '
              'callbacks.',
        );
        expect(
          _tooltipWithMessage(l10n.schoolWebImportEditAddress),
          findsOneWidget,
        );

        harness
            .pane(windowId: 41)
            .onLoadStop(
              popupController,
              WebUri('https://login.example.edu/popup'),
            );
        await tester.pump();
        await tester.pump();
        expect(
          tester
              .widget<IconButton>(
                _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
              )
              .onPressed,
          isNotNull,
        );

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();
        await tester.pump();
        expect(popupController.goBackCalls, 1);
        expect(find.text('pane-41'), findsOneWidget);

        popupController.canGoBackResult = false;
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();
        await tester.pump();
        expect(find.text('pane-41'), findsNothing);
        expect(find.text('pane-root'), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'Windows main-frame failure reports feedback without blocking import',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        harness.pane().onLoadStart(controller, WebUri(_site.loginUrl));
        await tester.pump();
        harness.pane().onProgressChanged(controller, 100);
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        controller.currentUrl = WebUri('https://identity.example.edu/lagging');
        harness.pane().onReceivedError(
          controller,
          WebResourceRequest(url: WebUri(_site.loginUrl), isForMainFrame: true),
          WebResourceError(
            description: 'Synthetic main-frame failure',
            type: WebResourceErrorType.UNKNOWN,
          ),
        );
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        expect(find.text(l10n.schoolWebImportLoadFailed), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          tester
              .widget<IconButton>(
                _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'address editor keeps invalid input visible, then cancels without a navigation',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        harness.pane().onLoadStop(controller, WebUri(_site.loginUrl));
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        final originalLoads = controller.loadedAddresses.length;
        await tester.tap(_tooltipWithMessage(l10n.schoolWebImportEditAddress));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'javascript:alert(1)');
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.schoolWebImportOpenAddress),
        );
        await tester.pump();

        expect(find.text(l10n.schoolWebImportAddressInvalid), findsOneWidget);
        expect(controller.loadedAddresses, hasLength(originalLoads));

        await tester.enterText(
          find.byType(TextField),
          'https://retry.example.edu/timetable',
        );
        await tester.pump();
        expect(find.text(l10n.schoolWebImportAddressInvalid), findsNothing);

        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(controller.loadedAddresses, hasLength(originalLoads));
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'popup fallback, duplicate panes, and native close requests retain one browser route',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: false,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();

        final fallback = CreateWindowAction(
          windowId: 73,
          request: URLRequest(
            url: WebUri('https://identity.example.edu/sign-in'),
          ),
          isForMainFrame: true,
        );
        expect(
          await harness.pane().onCreateWindow(controller, fallback),
          isTrue,
        );
        await tester.pump();
        expect(
          controller.loadedAddresses.last,
          'https://identity.example.edu/sign-in',
        );
        expect(find.text('pane-73'), findsNothing);

        final unsupported = CreateWindowAction(
          windowId: 74,
          request: URLRequest(url: WebUri('mailto:help@example.edu')),
          isForMainFrame: true,
        );
        expect(
          await harness.pane().onCreateWindow(controller, unsupported),
          isFalse,
        );
        await tester.pump();
        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        expect(
          find.text(l10n.schoolWebImportNewWindowUnsupported),
          findsOneWidget,
        );

        harness.pane().onCloseWindow(controller);
        await tester.pumpAndSettle();
        expect(find.text(l10n.schoolWebImportExitTitle), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(SchoolWebImportPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'duplicate popup requests activate one pane and child close returns to its parent',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final rootController = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(rootController);
        await tester.pump();

        final popup = CreateWindowAction(
          windowId: 75,
          request: URLRequest(
            url: WebUri('https://identity.example.edu/window'),
          ),
          isForMainFrame: true,
        );
        expect(
          await harness.pane().onCreateWindow(rootController, popup),
          isTrue,
        );
        await tester.pump();
        final popupController = _FakeWebViewController()
          ..currentUrl = WebUri('https://identity.example.edu/window');
        harness.pane(windowId: 75).onWebViewCreated(popupController);
        await tester.pump();

        expect(
          await harness.pane().onCreateWindow(rootController, popup),
          isTrue,
        );
        await tester.pump();
        expect(find.text('pane-75'), findsOneWidget);

        harness.pane(windowId: 75).onCloseWindow(popupController);
        await tester.pump();
        expect(find.text('pane-75'), findsNothing);
        expect(find.text('pane-root'), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'history and title callbacks keep a SPA page importable and invalidate stale page metadata',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        harness.pane().onLoadStop(controller, WebUri(_site.loginUrl));
        await tester.pump();
        await tester.pump();

        harness.pane().onTitleChanged(controller, 'Autumn timetable');
        harness.pane().onTitleChanged(controller, 'Autumn timetable');
        harness.pane().onUpdateVisitedHistory(
          controller,
          WebUri('https://portal.example.edu/timetable#week-2'),
          false,
        );
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        expect(find.text('portal.example.edu'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
              )
              .onPressed,
          isNotNull,
        );
        harness.pane().onUpdateVisitedHistory(
          controller,
          WebUri('https://portal.example.edu/timetable#week-2'),
          true,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'Android opens the school site immediately without a sign-in confirmation',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        expect(controller.loadedAddresses, <String>[_site.loginUrl]);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byTooltip(l10n.schoolWebImportExitBrowser), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'failed page extraction restores interaction and reports a retryable error',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        harness.pane().onLoadStop(controller, WebUri(_site.loginUrl));
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        controller.javascriptError = StateError('Synthetic extraction failure');
        await tester.tap(
          _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.importFailedCheckContent), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                _iconButtonWithTooltip(l10n.schoolWebImportImportCurrentPage),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'desktop navigation command failures clear their busy state and system Back falls back to exit confirmation',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final provider = await _createConfiguredProvider();
        addTearDown(provider.dispose);
        final harness = _WebViewHarness();
        final controller = _FakeWebViewController();

        await tester.pumpWidget(
          _browserApp(
            provider: provider,
            loadSites: () async => <SchoolSite>[_site],
            webViewBuilder: harness.build,
            supportsPopupWindows: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        harness.pane().onWebViewCreated(controller);
        await tester.pump();
        harness.pane().onLoadStop(controller, WebUri(_site.loginUrl));
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(SchoolWebImportPage));
        final l10n = AppLocalizations.of(context);
        controller.failLoad = true;
        await tester.tap(
          find.ancestor(
            of: find.byIcon(Icons.refresh),
            matching: find.byType(IconButton),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text(l10n.schoolWebImportLoadFailed), findsOneWidget);

        controller.failLoad = false;
        controller.canGoBackResult = true;
        harness.pane().onUpdateVisitedHistory(
          controller,
          WebUri('https://portal.example.edu/timetable/week-2'),
          false,
        );
        await tester.pump();
        await tester.pump();
        controller.failGoBack = true;
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();
        await tester.pump();
        expect(find.text(l10n.schoolWebImportLoadFailed), findsOneWidget);

        controller.failGoBack = false;
        controller.failCanGoBack = true;
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(l10n.schoolWebImportExitTitle), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(SchoolWebImportPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets('site loading has explicit empty and failure states', (
      tester,
    ) async {
      final provider = await _createConfiguredProvider();
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        _browserApp(
          provider: provider,
          loadSites: () async => <SchoolSite>[],
          supportsPopupWindows: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      final emptyContext = tester.element(find.byType(SchoolWebImportPage));
      expect(
        find.text(AppLocalizations.of(emptyContext).schoolWebImportNoSchools),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _browserApp(
          provider: provider,
          home: SchoolWebImportPage(
            key: const ValueKey<String>('school-load-failure'),
            site: _site,
            loadSites: () async => throw StateError('Synthetic site failure'),
            supportsPopupWindows: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final failureContext = tester.element(find.byType(SchoolWebImportPage));
      expect(
        find.text(
          AppLocalizations.of(failureContext).schoolWebImportSchoolLoadFailed,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
