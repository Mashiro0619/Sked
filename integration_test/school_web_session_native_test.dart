import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/services/school_web_session_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final embedded in [false, true]) {
    testWidgets(
      'isolated ${embedded ? 'embedded' : 'headless'} Windows WebView2 profile loses cookies and site storage',
      (tester) async {
        final profilePath = Platform.environment['WEBVIEW2_USER_DATA_FOLDER'];
        expect(profilePath, isNotNull);
        final profile = path.normalize(path.absolute(profilePath!));
        final temporaryRoot = path.normalize(
          path.absolute(Directory.systemTemp.path),
        );
        expect(
          path.isWithin(temporaryRoot, profile),
          isTrue,
          reason: 'This test must only clear a dedicated temporary browser profile.',
        );
        expect(path.basename(profile), startsWith('sked-web-session-qa-'));

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var seed = true;
        server.listen((request) async {
          request.response.headers.contentType = ContentType.html;
          request.response.write('''<!doctype html><html><body>School session QA
        <script>${seed ? "document.cookie = 'skedSession=synthetic; path=/'; localStorage.setItem('skedSession', 'synthetic');" : ''}</script>
        </body></html>''');
          await request.response.close();
        });
        final url = WebUri('http://127.0.0.1:${server.port}/');
        final service = SchoolWebSessionService(
          platform: TargetPlatform.windows,
        );
        HeadlessInAppWebView? browser;
        InAppWebViewController? embeddedController;
        Future<void> close() async {
          if (embedded) {
            final controller = embeddedController;
            await tester.pumpWidget(const SizedBox.shrink());
            if (controller != null) {
              await service.finishClosingBrowser(controller);
              embeddedController = null;
            }
          } else {
            await browser?.dispose();
            browser = null;
          }
        }

        addTearDown(() async {
          await close();
          service.dispose();
        });

        Future<InAppWebViewController> open() async {
          final loaded = Completer<InAppWebViewController>();
          if (embedded) {
            await tester.pumpWidget(
              MaterialApp(
                home: InAppWebView(
                  key: UniqueKey(),
                  initialUrlRequest: URLRequest(url: url),
                  onWebViewCreated: (controller) =>
                      embeddedController = controller,
                  onLoadStop: (controller, _) {
                    if (!loaded.isCompleted) loaded.complete(controller);
                  },
                ),
              ),
            );
            return loaded.future.timeout(const Duration(seconds: 30));
          }
          browser = HeadlessInAppWebView(
            initialUrlRequest: URLRequest(url: url),
            onLoadStop: (controller, _) {
              if (!loaded.isCompleted) loaded.complete(controller);
            },
          );
          await browser!.run();
          return loaded.future.timeout(const Duration(seconds: 30));
        }

        final initial = await open();
        expect(
          await initial.evaluateJavascript(
            source: "localStorage.getItem('skedSession')",
          ),
          'synthetic',
        );
        expect(
          await initial.evaluateJavascript(source: 'document.cookie'),
          contains('skedSession=synthetic'),
        );
        service.registerBrowser(close);
        await service.clear();

        seed = false;
        final reopened = await open();
        expect(
          await reopened.evaluateJavascript(
            source: "localStorage.getItem('skedSession')",
          ),
          isNull,
        );
        expect(
          await reopened.evaluateJavascript(source: 'document.cookie'),
          isEmpty,
        );
        await close();

        // Read the actual folder chosen by WebView2, not a guessed executable path.
        final actualProfile = await SchoolWebSessionService.windowsChannel
            .invokeMethod<String>('clear');
        await SchoolWebSessionService.windowsChannel.invokeMethod<void>(
          'release',
        );
        expect(actualProfile, isNotNull);
        expect(path.equals(path.normalize(actualProfile!), profile), isTrue);
        final evidence = <String, Object?>{
          'platform': Platform.operatingSystemVersion,
          'profile': actualProfile,
          'viewMode': embedded ? 'embedded' : 'headless',
          'nativeDisposeAcknowledged': embedded,
          'cookiesBefore': true,
          'siteStorageBefore': true,
          'cookiesAfter': false,
          'siteStorageAfter': false,
          'result': 'passed',
        };
        final output = Platform.environment['SKED_WEB_SESSION_QA_REPORT'];
        if (output != null) {
          await File(output).writeAsString(jsonEncode(evidence));
        }
      },
      skip:
          !Platform.isWindows ||
          Platform.environment['SKED_WEB_SESSION_NATIVE_QA'] != '1',
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
