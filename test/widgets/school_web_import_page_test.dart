import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('load completion rejects stale, partial, and timed-out callbacks', () {
    const url = 'https://school.example.test/timetable';

    expect(
      shouldAcceptSchoolWebImportLoadCompletion(
        isLoading: true,
        timedOut: false,
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
        timedOut: false,
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
        timedOut: false,
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
        timedOut: true,
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
        timedOut: false,
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

  test('Android school sign-in requires the broad transfer disclosure', () {
    expect(
      requiresSchoolWebImportSignInDisclosure(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(
      requiresSchoolWebImportSignInDisclosure(
        isWeb: false,
        platform: TargetPlatform.iOS,
      ),
      isFalse,
    );
    expect(
      requiresSchoolWebImportSignInDisclosure(
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
  });

  test('navigation decisions are globally serialized and bounded', () async {
    final requestedOrigins = <String>[];
    final decisions = <Completer<bool>>[];
    final queue = SchoolWebImportNavigationDecisionQueue(
      maxPendingOrigins: 2,
      decide: (origin) {
        requestedOrigins.add(origin);
        final decision = Completer<bool>();
        decisions.add(decision);
        return decision.future;
      },
    );
    addTearDown(queue.dispose);

    final first = queue.request('https://one.example.test');
    final duplicateFirst = queue.request('https://one.example.test');
    final second = queue.request('https://two.example.test');
    final rejected = queue.request('https://three.example.test');
    await Future<void>.delayed(Duration.zero);

    expect(requestedOrigins, ['https://one.example.test']);
    expect(await rejected, isFalse);

    decisions.single.complete(true);
    expect(await first, isTrue);
    expect(await duplicateFirst, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(requestedOrigins, [
      'https://one.example.test',
      'https://two.example.test',
    ]);

    decisions.last.complete(false);
    expect(await second, isFalse);

    final later = queue.request('https://later.example.test');
    await Future<void>.delayed(Duration.zero);
    expect(requestedOrigins.last, 'https://later.example.test');
    decisions.last.complete(true);
    expect(await later, isTrue);
  });

  test(
    'disposing navigation decisions rejects active and queued work',
    () async {
      final requestedOrigins = <String>[];
      final activeDecision = Completer<bool>();
      final queue = SchoolWebImportNavigationDecisionQueue(
        decide: (origin) {
          requestedOrigins.add(origin);
          return activeDecision.future;
        },
      );

      final active = queue.request('https://one.example.test');
      final queued = queue.request('https://two.example.test');
      await Future<void>.delayed(Duration.zero);
      queue.dispose();

      expect(await active, isFalse);
      expect(await queued, isFalse);
      expect(await queue.request('https://later.example.test'), isFalse);
      expect(requestedOrigins, ['https://one.example.test']);

      activeDecision.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(requestedOrigins, ['https://one.example.test']);
    },
  );

  test('HTTP school sign-in uses an explicit interception warning', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    final httpMessage = schoolWebImportSignInConsentMessage(
      l10n,
      'http://school.example.test',
    );
    final httpsMessage = schoolWebImportSignInConsentMessage(
      l10n,
      'https://school.example.test',
    );

    expect(
      httpMessage,
      contains('credentials and page content can be read or changed'),
    );
    expect(httpsMessage, isNot(contains('read or changed')));
  });

  test(
    'cross-origin navigation warns when the target downgrades to HTTP',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final httpMessage = schoolWebImportNavigationConsentMessage(
        l10n,
        'http://identity.example.test',
      );
      final httpsMessage = schoolWebImportNavigationConsentMessage(
        l10n,
        'https://identity.example.test',
      );

      expect(
        httpMessage,
        contains('credentials and page content can be read or changed'),
      );
      expect(httpsMessage, contains('another site'));
      expect(httpsMessage, isNot(contains('read or changed')));
    },
  );

  testWidgets('initial school load waits until inherited widgets are ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  testWidgets(
    'initial sign-in consent ignores repeated confirmation activation',
    (tester) async {
      bool? result;
      await _pumpSecurityDialogLauncher(
        tester,
        isInitialNavigation: true,
        onResult: (value) => result = value,
      );

      final confirmButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm'),
      );
      confirmButton.onPressed!();
      confirmButton.onPressed!();
      await tester.pumpAndSettle();

      expect(find.byKey(_securityDialogLauncherKey), findsOneWidget);
      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cross-origin consent ignores repeated cancellation activation', (
    tester,
  ) async {
    bool? result;
    await _pumpSecurityDialogLauncher(
      tester,
      isInitialNavigation: false,
      onResult: (value) => result = value,
    );

    final cancelButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    cancelButton.onPressed!();
    cancelButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(_securityDialogLauncherKey), findsOneWidget);
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale consent callback cannot pop the underlying page', (
    tester,
  ) async {
    bool? result;
    await _pumpSecurityDialogLauncher(
      tester,
      isInitialNavigation: true,
      onResult: (value) => result = value,
    );

    final staleConfirm = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
        .onPressed!;
    Navigator.of(
      tester.element(find.byKey(_securityDialogLauncherKey)),
      rootNavigator: true,
    ).pop(false);
    staleConfirm();
    await tester.pumpAndSettle();

    expect(find.byKey(_securityDialogLauncherKey), findsOneWidget);
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });
}

const _securityDialogLauncherKey = ValueKey('security-dialog-launcher');

Future<void> _pumpSecurityDialogLauncher(
  WidgetTester tester, {
  required bool isInitialNavigation,
  required ValueChanged<bool> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (rootContext) => Scaffold(
          body: FilledButton(
            onPressed: () {
              Navigator.of(rootContext).push(
                MaterialPageRoute<void>(
                  builder: (pageContext) => Scaffold(
                    key: _securityDialogLauncherKey,
                    body: FilledButton(
                      onPressed: () async {
                        onResult(
                          await showSchoolWebImportSecurityConsentDialog(
                            context: pageContext,
                            origin: isInitialNavigation
                                ? 'https://school.example.test'
                                : 'https://identity.example.test',
                            isInitialNavigation: isInitialNavigation,
                          ),
                        );
                      },
                      child: const Text('Open consent'),
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open page'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open page'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open consent'));
  await tester.pumpAndSettle();
}
